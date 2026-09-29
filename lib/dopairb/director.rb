# frozen_string_literal: true

module Dopairb
  # Picks a scene for each event and plays it. Bigger moments win; smaller
  # ones are folded into the subtitle instead of being queued.
  class Director
    FPS = 40.0

    attr_reader :config

    def initialize(config, rng: Random.new)
      @config = config
      @rng = rng
      @last_flash = -10.0
    end

    def ctx(input: nil, pre: 0.0, rows: nil, cols: nil)
      r, c = Term.size
      Ctx.new(w: (cols || c) - 1, rows: rows || r, depth: Term.depth(@config), config: @config, rng: @rng,
              input: input, pre: pre, compact: @config.level <= 1 || (cols || c) < 40)
    end

    def scene_for(event, ctx)
      info = event.info
      case event.kind
      when :interrupt then Scenes::Scatter.new(ctx, event)
      when :failure then failure_scene(info[:type], ctx, event)
      else success_scene(event, ctx)
      end
    end

    def failure_scene(type, ctx, event)
      case type
      when :syntax then Scenes::Crack.new(ctx, event)
      when :name then Scenes::Spotlight.new(ctx, event)
      when :nomethod then Scenes::Snap.new(ctx, event)
      when :type, :argument then Scenes::Clash.new(ctx, event)
      else Scenes::FailureScene.new(ctx, event)
      end
    end

    def success_scene(event, ctx)
      info = event.info
      alt = @config.max? && @config.motion
      mega = lambda do |text, palette, rainbow: false, sub: nil|
        if alt
          Scenes::Banner.new(self.ctx(rows: ctx.rows, cols: ctx.w + 1).tap { |c| c.depth = ctx.depth }, event, text: text, palette: palette, mega: true,
                                                                    rainbow: rainbow, sub: sub, alt: true)
        else
          Scenes::Banner.new(ctx, event, text: text, palette: palette, mega: true, rainbow: rainbow, sub: sub)
        end
      end
      if event.flag?(:comeback)
        mega.(event.streak >= 2 ? "COMEBACK!" : "FIXED!", Color::GOLD, rainbow: event.streak >= 2)
      elsif event.flag?(:eval_milestone)
        mega.("#{Fx.number_with_commas(event_evals(event))} EVALS", Color::NEON, rainbow: true)
      elsif event.flag?(:record_jump)
        mega.("NEW RECORD", Color::GOLD, rainbow: true, sub: number_text(info))
      elsif event.flag?(:combo_mega)
        mega.("COMBO #{event.combo}!", Color::FIRE, rainbow: event.combo >= 50)
      elsif info[:type] == :definition
        Scenes::Unlock.new(ctx, event)
      elsif event.flag?(:combo_milestone) && event.combo >= 5
        Scenes::Banner.new(ctx, event, text: "COMBO #{event.combo}", palette: Color::FIRE)
      elsif event.flag?(:first_hit)
        Scenes::Banner.new(ctx, event, text: "FIRST HIT!", palette: Color::ICE)
      elsif event.flag?(:output_rain)
        Scenes::Rain.new(ctx, event)
      else
        value_scene(event, ctx)
      end
    end

    def value_scene(event, ctx)
      info = event.info
      case info[:type]
      when :nil then Scenes::Puff.new(ctx, event)
      when :true, :false then Scenes::Stamp.new(ctx, event)
      when :integer, :float
        info[:value].abs >= 10_000 || event.flag?(:new_record) ? Scenes::Counter.new(ctx, event) : Scenes::Hit.new(ctx, event)
      when :huge
        Scenes::Banner.new(ctx, event, text: "HUGE", palette: Color::GOLD, sub: "#{Fx.number_with_commas(info[:digits])} DIGITS")
      when :string then info[:length] >= 40 ? Scenes::Stream.new(ctx, event) : Scenes::Hit.new(ctx, event)
      when :array, :hash then info[:size] > 0 ? Scenes::Crate.new(ctx, event) : Scenes::Hit.new(ctx, event)
      else Scenes::Hit.new(ctx, event)
      end
    end

    def play_event(event, input: nil, pre: 0.0)
      return if @config.off?
      c = ctx(input: input, pre: pre)
      c.input = nil if input && input.size + 12 > c.rows
      play(scene_for(event, c))
    end

    def intro
      return if @config.off? || !@config.intro
      play(Scenes::Intro.new(ctx), force_trail: true)
    end

    def outro(stats)
      return if @config.off?
      play(Scenes::Outro.new(ctx, stats), force_trail: true)
    end

    def play(scene, force_trail: false)
      animated = @config.motion && scene.ctx.w >= 20 && fits?(scene)
      animated = false if animated && Term.input_pending?
      run(scene) if animated
      Term.bell if @config.sound && scene.bell? && animated
      emit_trail(scene, force_trail)
    rescue Exception => e # rubocop:disable Lint/RescueException
      raise if SystemExit === e || (SignalException === e && !(Interrupt === e))
      # Never let an effect break the REPL; Ctrl-C during an effect just skips it.
    end

    private

    def event_evals(_event)
      Dopairb.session&.game&.evals.to_i
    end

    def number_text(info)
      Integer === info[:value] ? Fx.number_with_commas(info[:value]) : info[:value].to_s
    end

    def fits?(scene)
      top = scene.top? ? scene.ctx.input.size : 0
      alt = scene.is_a?(Scenes::Banner) && scene.height == scene.ctx.rows
      alt || scene.height + top <= scene.ctx.rows - 1
    end

    def emit_trail(scene, force)
      tr = scene.trail
      return unless tr
      ok = force || @config.trail == :all || (@config.trail == :big && scene.big?)
      return unless ok
      tr = tr.gsub(/\e\[[\d;]*m/, "") if scene.depth == :none
      Term.write(tr.gsub("\n", "\r\n") + "\e[0m\r\n")
    end

    def run(scene)
      alt = scene.is_a?(Scenes::Banner) && scene.height == scene.ctx.rows && scene.mega?
      top = !alt && scene.top? ? scene.ctx.input.rows : []
      stage = alt ? AltStage.new(scene.height) : Stage.new(scene.height, top: top)
      depth = scene.depth
      flash_off = nil
      Term.raw do
        stage.open
        t0 = now
        flashed = false
        begin
          loop do
            break if Term.input_pending? || !stage.open?
            t = (now - t0) / @config.duration
            break if t >= scene.total_length
            lines = []
            unless top.empty?
              tc = Canvas.new(scene.ctx.w, top.size)
              lines.concat(scene.draw_top(tc, t) ? tc.render(depth) : top)
            end
            ts = t - scene.pre
            c = Canvas.new(scene.ctx.w, scene.height)
            scene.draw(c, ts) if ts >= 0
            lines.concat(c.render(depth, shake: ts >= 0 ? scene.shake(ts) : 0))
            if !flashed && scene.flash_at && ts >= scene.flash_at
              flashed = true
              if @config.flash == :full && now - @last_flash > 0.4
                @last_flash = now
                Term.write("\e[?5h")
                flash_off = now + 0.05
              end
            end
            stage.draw(lines)
            if flash_off && now >= flash_off
              Term.write("\e[?5l")
              flash_off = nil
            end
            sleep(1 / FPS)
          end
        ensure
          Term.write("\e[?5l") if flash_off
          stage.close
        end
      end
    end

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
