# frozen_string_literal: true

module Dopairb
  module Scenes
    # Startup title: letters drop in one by one, each with its own impact.
    class Intro < Scene
      TITLE = "DOPA IRB"
      TAG = "every keystroke counts."

      def initialize(ctx, career = nil)
        @career = career
        super(ctx, nil)
      end

      def big? = true
      def sfx = :intro
      def impact_at = 0.2

      # "LV 5  *  DAY 3 STREAK!" or nil on a fresh profile.
      def career_line
        return nil unless @career
        bits = []
        bits << "LV #{@career[:level]}" if @career[:level].to_i > 1
        bits << "DAY #{@career[:streak]} STREAK#{'!' if @career[:streak_up]}" if @career[:streak].to_i >= 2
        bits.empty? ? nil : bits.join("  #{Term.glyph('✦', '*')}  ")
      end

      def setup
        @scale = best_scale(TITLE)
        @parts = Fx::Particles.new(@rng)
        return unless @scale
        @letters = []
        x = (@w - Font.width(TITLE, scale: @scale)) / 2
        TITLE.each_char.with_index do |ch, i|
          lw = Font.width(ch, scale: @scale)
          at = 0.08 + i * 0.07
          @letters << [ch, x, at]
          unless ch == " "
            @parts.burst(x + lw / 2.0, 6, 12, at: at + 0.12, speed: 30, life: 0.45, palette: Color.const_get(%i[FIRE GOLD NEON ICE TOXIC][i % 5]),
                                              gravity: 20, angle: -Math::PI / 2, arc: Math::PI * 1.4)
          end
          x += lw + @scale
        end
      end

      def height = @scale ? 9 : 2
      def length = 1.35

      def shake(t)
        return 0 unless @letters
        @letters.any? { |_, _, at| (t - at - 0.12).between?(0, 0.05) } ? (@rng.rand(3) - 1) : 0
      end

      def draw(c, t)
        unless @scale
          c.put(1, 0, "D O P A   I R B", Color.rainbow(t), bold: true)
          c.put(1, 1, TAG, [200, 200, 210]) if t > 0.4
          return
        end
        @letters.each_with_index do |(ch, x, at), i|
          lt = t - at
          next if lt < 0
          y = lt < 0.12 ? 1 - ((1 - Fx.ease_in(lt / 0.12)) * 7).round : 1
          fn = lambda do |_rx, ry, _f|
            base = Color.rainbow(i / 9.0 - t * 0.6 + ry * 0.02, 0.75)
            lt < 0.2 ? Color.mix([255, 255, 255], base, lt / 0.2) : base
          end
          Fx.big_text(c, ch, x, y, fn, scale: @scale)
        end
        @parts.draw(c, t)
        Fx.sparkles(c, t, 11, 16, palette: Color::GOLD) if t > 0.7
        tag = [career_line, TAG].compact.join("   ")
        tag = TAG if tag.size > @w
        n = (tag.size * Fx.phase(t, 0.75, 1.1)).round
        c.put_center(7, tag[0, n], [230, 230, 240], bold: true) if n > 0
      end

      def trail
        star = Term.glyph("✦", "*")
        title = "#{star} DOPA IRB #{VERSION} #{star}"
        colored = depth == :none ? title : title.each_char.with_index.map { |ch, i| "#{Color.sgr(Color.rainbow(i / 22.0), nil, true, depth)}#{ch}" }.join + "\e[0m"
        career = career_line
        career = career ? "#{paint(career, [255, 215, 120], bold: true)}  " : ""
        "#{colored}  #{career}#{paint("Ruby #{RUBY_VERSION}  --  type `dopa` for effect settings", [150, 150, 165])}"
      end
    end

    # Session result screen. Leaves a plain text table behind.
    class Outro < Scene
      def big? = true
      def sfx = :result

      def initialize(ctx, stats)
        @stats = stats
        super(ctx, nil)
      end

      def rows_data
        s = @stats
        [
          ["EVALS", s[:evals]],
          ["HITS", s[:successes]],
          ["ERRORS", s[:failures]],
          ["INTERRUPTS", s[:interrupts]],
          ["MAX COMBO", s[:max_combo]],
          ["KEYSTROKES", s[:keystrokes]],
          ["SCORE", s[:score]],
        ]
      end

      def setup
        @scale = Fx.text_fits?("RESULT", @w) ? 1 : nil
        @parts = Fx::Particles.new(@rng)
        @parts.burst(@w / 2.0, 3, 60, at: 0.25, speed: 50, life: 0.7, palette: Color::GOLD, gravity: 12)
      end

      def height = (@scale ? 6 : 1) + rows_data.size + 2
      def length = 1.6
      def flash_at = 0.25

      def draw(c, t)
        y = 0
        if @scale
          fn = ->(_rx, ry, f) { Color.rainbow(f * 0.6 - t * 0.5 + ry * 0.03, 0.7) }
          drop = t < 0.25 ? ((1 - Fx.ease_in(t / 0.25)) * 6).round : 0
          Fx.big_text(c, "RESULT", (@w - Font.width("RESULT")) / 2, 0 - drop, fn)
          @parts.draw(c, t)
          y = 6
        else
          c.put(1, 0, "R E S U L T", Color.rainbow(t), bold: true)
          y = 1
        end
        x = [(@w - 34) / 2, 1].max
        rows_data.each_with_index do |(k, v), i|
          at = 0.3 + i * 0.1
          next if t < at
          p = Fx.phase(t, at, at + 0.35)
          shown = Fx.number_with_commas((v * Fx.ease_out(p)).round)
          c.put(x, y + i, k.ljust(14, "."), [160, 160, 175])
          col = k == "SCORE" ? Color.rainbow(t) : (p < 1 ? [255, 255, 255] : [255, 220, 130])
          c.put(x + 14, y + i, shown.rjust(16), col, bold: true)
        end
        at = 0.3 + rows_data.size * 0.1
        c.put(x, y + rows_data.size, "TIME".ljust(14, "."), [160, 160, 175]) if t > at
        c.put(x + 14, y + rows_data.size, clock(@stats[:time]).rjust(16), [255, 220, 130], bold: true) if t > at
        Fx.sparkles(c, t, 5, 14, palette: Color::GOLD) if t > 0.8
      end

      def trail
        x = "  "
        lines = [paint("#{x}#{Term.glyph('✦', '*')} DOPA IRB RESULT #{Term.glyph('✦', '*')}", [255, 210, 110], bold: true)]
        rows_data.each { |k, v| lines << "#{x}#{k.ljust(12)}#{Fx.number_with_commas(v).rjust(14)}" }
        lines << "#{x}#{'TIME'.ljust(12)}#{clock(@stats[:time]).rjust(14)}"
        lines.join("\n")
      end

      private

      def clock(sec)
        sec = sec.to_i
        h, rest = sec.divmod(3600)
        m, s = rest.divmod(60)
        h > 0 ? format("%dh%02dm%02ds", h, m, s) : format("%dm%02ds", m, s)
      end
    end
  end
end

module Dopairb
  module Scenes
    # Shown at startup while the startup sound is being synthesized.
    # A cat runs along a pastel progress bar; LOADING bounces; sparkles pop.
    class Loading < Scene
      PASTEL = [[255, 170, 210], [255, 205, 160], [255, 245, 170], [180, 245, 200], [170, 215, 255], [215, 185, 255]].freeze
      MESSAGES = ["tuning the synthesizer", "polishing sparkles", "charging the combo meter",
                  "stacking fireworks", "waking up the cat"].freeze
      MIN = 0.7
      FINISH = 0.45

      def initialize(ctx, ready)
        @ready = ready
        @ready_at = nil
        super(ctx, nil)
      end

      def height = 6
      def length = 8.0 # safety net; normally ends via done?

      def setup
        @parts = Fx::Particles.new(@rng)
        @bar_x = 4
        @bar_w = [[@w - 12, 60].min, 16].max
      end

      def done?(t)
        if @ready_at.nil? && t >= MIN && @ready.call
          @ready_at = t
          @parts.burst(@bar_x + @bar_w, 3, 40, at: t, speed: 40, life: 0.5, palette: PASTEL, gravity: 10)
        end
        @ready_at && t >= @ready_at + FINISH
      end

      def progress(t)
        fake = 1 - Math.exp(-t / 0.9) # creeps towards 1, never gets there
        return 0.9 * fake unless @ready_at
        0.9 * fake + (1 - 0.9 * fake) * Fx.ease_out((t - @ready_at) / 0.2)
      end

      def pastel(i, t) = Color.ramp(PASTEL, ((i * 0.13 + t * 0.6) % 1.0))

      def draw(c, t)
        Fx.sparkles(c, t, 21, 18, palette: PASTEL.reverse)
        draw_word(c, t)
        draw_bar(c, t)
        @parts.draw(c, t)
        msg = if @ready_at then "ready!  #{Term.glyph('✦', '*')}"
              else "#{MESSAGES[(t / 0.9).to_i % MESSAGES.size]}#{'.' * ((t * 4).to_i % 4)}"
              end
        c.put(@bar_x, 5, msg, @ready_at ? [255, 240, 170] : [200, 190, 230], bold: !@ready_at.nil?)
      end

      private

      def draw_word(c, t)
        word = @ready_at ? "READY!" : "LOADING"
        x = @bar_x
        word.each_char.with_index do |ch, i|
          hop = Math.sin(t * 9 - i * 0.7)
          y = hop > 0.55 ? 0 : 1
          c.put(x, y, ch, pastel(i, t), bold: true)
          x += 2
        end
      end

      def draw_bar(c, t)
        p = progress(t)
        filled = (p * @bar_w).round
        y = 3
        @bar_w.times do |i|
          if i < filled
            shimmer = ((i - t * 40) % 14).abs < 1.5
            c.bg(@bar_x + i, y, shimmer ? [255, 255, 255] : pastel(i / 3, t))
          else
            c.put(@bar_x + i, y, Term.glyph("⣀", "."), [90, 80, 110])
          end
        end
        run = (t * 10).to_i.even?
        cat = @ready_at ? "=^o^=" : (run ? "=^.^=" : "=^-^=")
        bounce = @ready_at && t - @ready_at < 0.25 ? 1 : (run ? 0 : 1)
        cx = @bar_x + [filled - 2, 0].max
        c.put(cx, y - 1 - bounce, cat, [255, 220, 235], bold: true)
        c.put(cx - 2, y - 1, run ? "~" : "'", [255, 190, 220]) if !@ready_at && t % 0.2 < 0.1
        pct = "#{(p * 100).floor}%"
        c.put(@bar_x + @bar_w + 2, y, pct, [255, 240, 200], bold: true)
      end
    end
  end
end
