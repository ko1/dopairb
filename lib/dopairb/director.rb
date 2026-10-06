# frozen_string_literal: true

module Dopairb
  # Picks a scene for each event and plays it. Bigger moments win; smaller
  # ones are folded into the subtitle instead of being queued.
  class Director
    FPS = 40.0

    attr_reader :config, :rng

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
      full = lambda { self.ctx(rows: ctx.rows, cols: ctx.w + 1).tap { |c| c.depth = ctx.depth } }
      if event.flag?(:jackpot)
        Scenes::Jackpot.new(ctx, event)
      elsif event.flag?(:level_up) || (event.flag?(:art_drop) && info[:art])
        if @config.motion && @config.level >= 2 && info[:art] && Scenes::Masterpiece.fits?(ctx.rows, ctx.w + 1)
          Scenes::Masterpiece.new(full.(), event)
        elsif event.flag?(:level_up)
          mega.("LEVEL UP!", Color::NEON, rainbow: true, sub: "LV #{event.level}")
        else
          Scenes::Banner.new(ctx, event, text: "ART DROP!", palette: Color::GOLD, sub: Gallery.find(info[:art])&.title)
        end
      elsif event.flag?(:comeback)
        mega.(event.streak >= 2 ? "COMEBACK!" : "FIXED!", Color::GOLD, rainbow: event.streak >= 2)
      elsif event.flag?(:eval_milestone)
        mega.("#{Fx.number_with_commas(event_evals(event))} EVALS", Color::NEON, rainbow: true)
      elsif event.flag?(:record_jump)
        mega.("NEW RECORD", Color::GOLD, rainbow: true, sub: number_text(info))
      elsif event.flag?(:combo_mega)
        mega.("COMBO #{event.combo}!", Color::FIRE, rainbow: event.combo >= 50, sub: event.flag?(:fever_start) ? "FEVER TIME! ALL POINTS x2" : nil)
      elsif event.flag?(:combo_best)
        Scenes::Banner.new(ctx, event, text: "BEST COMBO!", palette: Color::FIRE, sub: "ALL-TIME BEST #{event.combo}")
      elsif info[:type] == :definition
        Scenes::Unlock.new(ctx, event)
      elsif event.flag?(:combo_milestone) && event.combo >= 5
        Scenes::Banner.new(ctx, event, text: "COMBO #{event.combo}", palette: Color::FIRE)
      elsif event.flag?(:first_hit)
        Scenes::Banner.new(ctx, event, text: "FIRST HIT!", palette: Color::ICE)
      elsif event.flag?(:critical) && !counter?(event)
        Scenes::Critical.new(ctx, event)
      elsif event.flag?(:output_rain)
        Scenes::Rain.new(ctx, event)
      else
        value_scene(event, ctx)
      end
    end

    def counter?(event)
      v = event.info[:value]
      %i[integer float].include?(event.info[:type]) && (v.abs >= 10_000 || event.flag?(:new_record))
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
      scene = scene_for(event, c)
      play(scene)
      encore(event, c) if Scenes::Jackpot === scene
      scene
    end

    # A jackpot pays out a masterpiece too: too good to fold away.
    def encore(event, c)
      return unless event.info[:art] && @config.motion && @config.level >= 2
      return if Term.input_pending? || !Scenes::Masterpiece.fits?(c.rows, c.w + 1)
      full = ctx(rows: c.rows, cols: c.w + 1).tap { |x| x.depth = c.depth }
      play(Scenes::Masterpiece.new(full, event))
    end

    # Cute loading screen until ready.call is true (e.g. the intro sound exists).
    def loading(&ready)
      return if @config.off?
      scene = Scenes::Loading.new(ctx, ready)
      return unless @config.motion && fits?(scene)
      run(scene)
    rescue Exception => e # rubocop:disable Lint/RescueException
      raise if SystemExit === e || (SignalException === e && !(Interrupt === e))
    end

    def intro(career = nil)
      return if @config.off? || !@config.intro
      play(Scenes::Intro.new(ctx, career), force_trail: true)
    end

    def outro(stats)
      return if @config.off?
      c = ctx
      scene = if @config.motion && Scenes::Finale.fits?(c.rows, c.w + 1) && @config.level >= 2
                Scenes::Finale.new(c, stats)
              else
                Scenes::Outro.new(c, stats)
              end
      # render the synced track now so it does not start late
      Sound.file(scene.sfx, @config.duration) if @config.sound == :sfx && scene.sfx && Sound.available?
      play(scene, force_trail: true)
    end

    def play(scene, force_trail: false)
      animated = @config.motion && scene.ctx.w >= 20 && fits?(scene)
      animated = false if animated && Term.input_pending?
      sound(scene, animated) unless !animated && @config.motion
      run(scene) if animated
      emit_trail(scene, force_trail)
    rescue Exception => e # rubocop:disable Lint/RescueException
      raise if SystemExit === e || (SignalException === e && !(Interrupt === e))
      # Never let an effect break the REPL; Ctrl-C during an effect just skips it.
      Dopairb.debug(e) unless Interrupt === e
    end

    private

    def sound(scene, animated)
      case @config.sound
      when :bell
        Term.bell if scene.bell?
      when :sfx
        if Sound.available?
          delay = animated ? (scene.pre + scene.impact_at) * @config.duration : 0.0
          Sound.play(scene.sfx, delay: delay, stretch: @config.duration) if scene.sfx
        elsif scene.bell?
          Term.bell
        end
      end
    end

    def event_evals(_event)
      Dopairb.session&.game&.evals.to_i
    end

    def number_text(info)
      Integer === info[:value] ? Fx.number_with_commas(info[:value]) : info[:value].to_s
    end

    def fits?(scene)
      top = scene.top? ? scene.ctx.input.size : 0
      scene.alt? || scene.height + top <= scene.ctx.rows - 1
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
      alt = scene.alt?
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
            break if t >= scene.total_length || scene.done?(t)
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
