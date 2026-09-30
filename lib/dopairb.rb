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
require_relative "dopairb/scene"
require_relative "dopairb/scenes/success"
require_relative "dopairb/scenes/failure"
require_relative "dopairb/scenes/session"
require_relative "dopairb/scenes/finale"
require_relative "dopairb/director"
require_relative "dopairb/output_tap"
require_relative "dopairb/charge_line"
require_relative "dopairb/sound"
require_relative "dopairb/input_fx"
require_relative "dopairb/reline_adapter"
require_relative "dopairb/irb_adapter"
require_relative "dopairb/session"
require_relative "dopairb/demo"

# dopairb: IRB where every keystroke, result and exception gets a show.
#
#   $ dopairb                 # or, in ~/.irbrc:  require "dopairb"; Dopairb.enable
module Dopairb
  class << self
    attr_reader :session

    def config
      @config ||= begin
        c = Config.new
        c.apply_string(ENV["DOPAIRB"]) if ENV["DOPAIRB"]
        c
      rescue ArgumentError => e
        warn "dopairb: ignoring DOPAIRB=#{ENV['DOPAIRB'].inspect}: #{e.message}"
        Config.new
      end
    end

    # Hook into IRB. Safe to call more than once; options are config settings.
    def enable(intro: nil, **settings)
      settings.each { |k, v| config.set(k, v) }
      config.set(:intro, intro) unless intro.nil?
      @session ||= Session.new(config)
      if IrbAdapter.install
        RelineAdapter.install(@session.fx)
        OutputTap.install
        Sound.warm_up(config.duration) if active?
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
      dopa KEY=VALUE ...    change one setting, e.g. `dopa flash=off duration=0.5`

      settings:
    TXT

    def command(arg)
      words = arg.split
      if words.empty? || words == ["status"]
        s = @session&.game
        puts "dopairb #{VERSION}  (#{active? ? 'active' : 'inactive: not a terminal or intensity=off'})"
        puts config.describe
        puts "  session: #{s.evals} evals, #{s.successes} hits, #{s.failures} errors, max combo #{s.max_combo}, score #{Fx.number_with_commas(s.score)}" if s
      elsif words == ["help"]
        puts HELP + config.describe
      elsif words == ["demo"]
        Demo.run(self)
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
