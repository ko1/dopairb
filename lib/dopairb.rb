# frozen_string_literal: true

require "monitor"
require "irb"
require "reline"
begin
  require "prism"
rescue LoadError
  nil
end

require_relative "dopairb/version"
require_relative "dopairb/config"
require_relative "dopairb/color"
require_relative "dopairb/term"
require_relative "dopairb/canvas"
require_relative "dopairb/font"
require_relative "dopairb/fx"
require_relative "dopairb/stage"
require_relative "dopairb/game"
require_relative "dopairb/probe"
require_relative "dopairb/profile"
require_relative "dopairb/gallery"
require_relative "dopairb/scene"
require_relative "dopairb/scenes/success"
require_relative "dopairb/scenes/failure"
require_relative "dopairb/scenes/session"
require_relative "dopairb/scenes/finale"
require_relative "dopairb/scenes/bonus"
require_relative "dopairb/director"
require_relative "dopairb/output_tap"
require_relative "dopairb/charge_line"
require_relative "dopairb/sound"
require_relative "dopairb/input_fx"
require_relative "dopairb/reline_adapter"
require_relative "dopairb/irb_adapter"
require_relative "dopairb/session"
require_relative "dopairb/demo"
require_relative "dopairb/tour"

# dopairb: IRB where every keystroke, result and exception gets a show.
#
#   $ dopairb                 # or, in ~/.irbrc:  require "dopairb"; Dopairb.enable
module Dopairb
  class << self
    attr_reader :session

    def config
      @config ||= begin
        c = Config.new
        if ENV["DOPAIRB"]
          c.apply_string(ENV["DOPAIRB"])
          overrides << [:string, ENV["DOPAIRB"]]
        end
        c
      rescue ArgumentError => e
        warn "dopairb: ignoring DOPAIRB=#{ENV['DOPAIRB'].inspect}: #{e.message}"
        Config.new
      end
    end

    # Settings for this run only ($DOPAIRB, dopairb options). They win over
    # Dopairb.enable(...) in .irbrc, which IRB loads after they are applied.
    def overrides = (@overrides ||= [])

    def override(name, value)
      name == :string ? config.apply_string(value) : config.set(name, value)
      overrides << [name, value]
    end

    # Hook into IRB. Safe to call more than once; options are config settings.
    def enable(intro: nil, **settings)
      settings.each { |k, v| config.set(k, v) }
      config.set(:intro, intro) unless intro.nil?
      overrides.each { |k, v| k == :string ? config.apply_string(v) : config.set(k, v) }
      @session ||= Session.new(config)
      if IrbAdapter.install
        RelineAdapter.install(@session.fx)
        OutputTap.install
        if active?
          # decided before warming up: the first run shows the loading screen
          @session.cold_start = Sound.available? && !Sound.ready?(:intro, config.duration)
          Sound.warm_up(config.duration)
        end
      else
        warn "dopairb: IRB #{defined?(IRB::VERSION) ? IRB::VERSION : '?'} is not supported; running plain IRB"
      end
      @session
    end

    def active?
      @session&.active? || false
    end

    def debug(e)
      return unless ENV["DOPAIRB_DEBUG"]
      File.open(ENV["DOPAIRB_DEBUG"], "a") { |f| f.puts "#{e.class}: #{e.message}", *e.backtrace&.first(8) }
    rescue StandardError
      nil
    end

    PRESETS = {
      "off" => { intensity: :off },
      "low" => { intensity: :low },
      "normal" => { intensity: :normal },
      "max" => { intensity: :max },
      "calm" => { intensity: :low, flash: :off, duration: 0.7 },
      "party" => { intensity: :max, flash: :full, sound: :sfx, duration: 1.0 },
    }.freeze

    HELP = <<~TXT
      dopa                  show settings and session stats
      dopa off|low|normal|max
      dopa calm             low intensity, no flash, shorter
      dopa party            max intensity, full-screen flash, sound effects
      dopa demo             play every effect once
      dopa loading          show the loading screen
      dopa gallery          the bonus art you have collected (dopa gallery NAME shows one)
      dopa gallery tour     a slideshow of all 100 (uncollected ones as silhouettes)
      dopa KEY=VALUE ...    change one setting, e.g. `dopa flash=off duration=0.5`

      settings:
    TXT

    def gallery(name)
      owned = ((@session&.profile&.gallery || []) + (@session&.collected || [])).uniq
      if name == "tour"
        return puts("dopairb: the tour needs a terminal") unless Term.interactive?
        return Tour.run(config, owned)
      end
      if name.nil?
        puts "dopairb gallery: #{owned.size}/#{Gallery::PIECES.size}  (level-ups, jackpots and lucky ART DROPs bring more)"
        Gallery::PIECES.each do |p|
          puts format("  %-32s %s -- %s, %s", p.id, p.title, p.artist, p.year) if owned.include?(p.id)
        end
        rest = Gallery::PIECES.size - owned.size
        puts "  ... #{rest} more to discover" if rest > 0
        puts "  `dopa gallery NAME` shows one; `dopa gallery tour` walks through all #{Gallery::PIECES.size}"
        return
      end
      piece = Gallery.find(name.to_sym) if Gallery.ids.include?(name.to_sym)
      return puts("dopairb: no such piece #{name.inspect}") unless piece
      return puts("dopairb: not unlocked yet -- keep playing!") unless owned.include?(piece.id)
      cols = [Term.cols - 1, 100].min
      w, h = Gallery.fit(piece, cols, [Term.rows - 4, 30].min)
      c = Canvas.new(w, h / 2)
      Gallery.draw(c, piece, 0, 0, w, h, depth: Term.depth(config))
      puts c.render(Term.depth(config))
      puts "\"#{piece.title}\"  #{piece.artist}, #{piece.year}"
    end

    def command(arg)
      words = arg.split
      if words.empty? || words == ["status"]
        s = @session&.game
        puts "dopairb #{VERSION}  (#{active? ? 'active' : 'inactive: not a terminal or intensity=off'})"
        puts config.describe
        puts "  sound player: #{Sound.backend ? Sound.backend[1].first : '(none; bell only)'}   cache: #{Sound.dir}"
        puts "  session: #{s.evals} evals, #{s.successes} hits, #{s.failures} errors, max combo #{s.max_combo}, score #{Fx.number_with_commas(s.score)}" if s
        prof = @session&.profile
        if prof&.persistent?
          lv = s.leveling? ? s.level : prof.level
          xp = s.leveling? ? s.xp : prof.xp
          puts "  career: LV #{lv} (#{Fx.number_with_commas(xp)} / #{Fx.number_with_commas(Game.xp_for(lv + 1))} XP), " \
               "best score #{Fx.number_with_commas(prof.best_score)}, best combo #{prof.best_combo}, day streak #{prof.streak}, " \
               "gallery #{prof.gallery.size}/#{Gallery::PIECES.size}   (#{prof.path})"
        end
      elsif words == ["help"]
        puts HELP + config.describe
      elsif words == ["demo"]
        Demo.run(self)
      elsif words[0] == "gallery"
        gallery(words[1])
      elsif words == ["loading"]
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @session&.director&.loading { Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0 > 2.5 } if active?
      elsif words.size == 1 && PRESETS.key?(words[0])
        PRESETS[words[0]].each { |k, v| config.set(k, v) }
        Sound.warm_up(config.duration) if active?
        puts "dopairb: #{words[0]}"
      else
        words.each do |w|
          k, v = w.split("=", 2)
          raise ArgumentError, "expected KEY=VALUE, got #{w.inspect}" unless v
          config.set(k, v)
        end
        Sound.warm_up(config.duration) if active?
        puts "dopairb: " + words.join(" ")
      end
      nil
    rescue ArgumentError => e
      puts "dopairb: #{e.message}"
      nil
    end
  end
end
