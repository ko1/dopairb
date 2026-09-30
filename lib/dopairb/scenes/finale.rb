# frozen_string_literal: true

module Dopairb
  module Scenes
    # Full-screen session result: title drop, stats slam in one by one,
    # drum-rolled total score, a rank stamp and fireworks. The :finale sound
    # is one track built on the same timeline (Finale::Timeline).
    class Finale < Scene
      module Timeline
        DROP = 0.35
        ROW0 = 0.55
        ROW_GAP = 0.17
        SLIDE = 0.08
        COUNT = 0.24
        ROWS = 8

        module_function

        def row_start(i) = ROW0 + i * ROW_GAP
        def row_land(i) = row_start(i) + SLIDE + COUNT
        def score_start = row_land(ROWS - 1) + 0.15
        def score_land = score_start + 0.85
        def rank = score_land + 0.3
        def length = rank + 1.9
      end

      T = Timeline
      NOTES = [1047, 1175, 1319, 1397, 1568, 1760, 1976, 2093].freeze

      RANKS = [[15_000, "S"], [6_000, "A"], [2_000, "B"], [0, "C"]].freeze
      RANK_PALETTE = { "S" => Color::NEON, "A" => Color::GOLD, "B" => Color::ICE, "C" => Color::TOXIC }.freeze

      def self.rank_for(stats)
        RANKS.find { |min, _| stats[:score].to_i >= min }[1]
      end

      # A cheerful title; never a verdict on the code.
      def self.title_for(s)
        if s[:max_combo].to_i >= 20 then "COMBO LEGEND"
        elsif s[:comebacks].to_i >= 3 then "COMEBACK KID"
        elsif s[:max_combo].to_i >= 10 then "COMBO MASTER"
        elsif s[:failures].to_i >= 3 && s[:successes].to_i > s[:failures].to_i then "NEVER GIVE UP"
        elsif s[:keystrokes].to_i >= 2000 then "IRON FINGERS"
        elsif s[:evals].to_i >= 100 then "MARATHONER"
        elsif s[:best_typing].to_i >= 60 then "SPEED TYPER"
        else "WELL PLAYED"
        end
      end

      def self.fits?(rows, cols) = rows >= 20 && cols >= 61

      def initialize(ctx, stats)
        @stats = stats
        super(ctx, nil)
      end

      def alt? = true
      def big? = true
      def mega? = true
      def height = ctx.rows
      def length = T.length
      def sfx = :finale
      def impact_at = 0.0
      def flash_at = T.score_land

      def rows_data
        s = @stats
        [
          ["EVALS", s[:evals]],
          ["HITS", s[:successes]],
          ["ERRORS", s[:failures]],
          ["COMEBACKS", s[:comebacks].to_i],
          ["MAX COMBO", s[:max_combo]],
          ["KEYSTROKES", s[:keystrokes]],
          ["INTERRUPTS", s[:interrupts]],
          ["TIME", s[:time].to_f],
        ]
      end

      def setup
        @h = ctx.rows
        @rank = self.class.rank_for(@stats)
        @title = self.class.title_for(@stats)
        @rpal = RANK_PALETTE[@rank]
        @tscale = Font.width("RESULT", scale: 2) <= @w - 4 ? 2 : 1
        @two_col = @w >= 80
        @big_score = @h >= 23
        @table_x = @two_col ? @w / 2 - 38 : (@w - 34) / 2
        @table_y = 8
        @panel = [@w / 2 + 4, @table_y, 30, 9] if @two_col
        @score_y = @h - 7
        @score = @stats[:score].to_i
        @stars = Array.new(80) { [@rng.rand(@w), @rng.rand(@h), @rng.rand, 0.4 + @rng.rand] }
        build_particles
      end

      def build_particles
        @parts = Fx::Particles.new(@rng)
        tw = Font.width("RESULT", scale: @tscale)
        @parts.burst(@w / 2.0, 6, 70, at: T::DROP, speed: 60, life: 0.6, palette: Color::GOLD, gravity: 18,
                                      angle: -Math::PI / 2, arc: Math::PI * 1.5)
        8.times { |i| @parts.burst((@w - tw) / 2.0 + tw * i / 7.0, 5.5, 5, at: T::DROP, speed: 30, life: 0.45, palette: Color::FIRE, gravity: 20) }
        T::ROWS.times do |i|
          @parts.burst(@table_x + 31, @table_y + i + 0.5, 10, at: T.row_land(i), speed: 22, life: 0.35,
                                                              palette: Color::GOLD, gravity: 8)
        end
        cy = @big_score ? @score_y + 2.5 : @table_y + 4
        @parts.burst(@w / 2.0, cy, 140, at: T.score_land, speed: 90, life: 0.8, palette: Color::GOLD, gravity: 16)
        @parts.burst(@w / 2.0, cy, 50, at: T.score_land + 0.03, speed: 55, life: 0.7, palette: Color::FIRE, gravity: 12,
                                       glyphs: ["*", "+", Term.glyph("✦", "*"), "'"])
        if @panel
          px, py, pw, ph = @panel
          @parts.burst(px + pw / 2.0, py + ph / 2.0, 60, at: T.rank, speed: 45, life: 0.55,
                                                         palette: [[255, 255, 255], *@rpal[0, 3]], gravity: 14)
        end
        @fire = Fx::Particles.new(@rng)
        pals = [Color::FIRE, Color::ICE, Color::NEON, Color::TOXIC, Color::GOLD]
        10.times do |i|
          at = T.rank + 0.2 + i * 0.13
          x = 4 + @rng.rand * (@w - 8)
          y = 2 + @rng.rand * (@h * 0.45)
          @fire.add(x, @h.to_f, 0, -(@h - y) / 0.15 * 2, at: at - 0.15, life: 0.15, palette: [[255, 255, 255], [255, 200, 120]])
          @fire.burst(x, y, 55, at: at, speed: 50, life: 0.9, palette: pals[i % pals.size], gravity: 9, drag: 2.2)
        end
        90.times do
          @fire.add(@rng.rand * @w, -1, (@rng.rand - 0.5) * 5, 3 + @rng.rand * 5, at: T.rank + @rng.rand * 1.4, life: 1.8,
                                                                                palette: [Color.rainbow(@rng.rand), Color.rainbow(@rng.rand)],
                                                                                glyph: ["*", "+", "'", ",", Term.glyph("✦", "*")][@rng.rand(5)], gravity: 1.2)
        end
      end

      def shake(t)
        [[T::DROP, 4, 0.3], [T.score_land, 6, 0.4], [T.rank, 4, 0.3]].each do |at, amp, len|
          age = t - at
          return ((@rng.rand * 2 - 1) * amp * (1 - age / len)).round if age >= 0 && age < len
        end
        0
      end

      def draw(c, t)
        draw_stars(c, t)
        flash(c, t)
        draw_title(c, t)
        draw_table(c, t)
        draw_score(c, t)
        draw_rank(c, t)
        @parts.draw(c, t)
        @fire.draw(c, t)
        draw_footer(c, t)
      end

      def trail
        x = "  "
        star = Term.glyph("✦", "*")
        lines = [paint("#{x}#{star} DOPA IRB RESULT #{star}", [255, 210, 110], bold: true)]
        rows_data.each { |k, v| lines << "#{x}#{k.ljust(12)}#{value_text(k, v).rjust(14)}" }
        lines << paint("#{x}#{'SCORE'.ljust(12)}#{Fx.number_with_commas(@score).rjust(14)}", [255, 220, 130], bold: true)
        lines << paint("#{x}#{'RANK'.ljust(12)}#{@rank.rjust(14)}  #{@title}", Color.ramp(@rpal, 0.2), bold: true)
        lines.join("\n")
      end

      private

      def value_text(k, v)
        k == "TIME" ? clock(v) : Fx.number_with_commas(v.to_i)
      end

      def draw_stars(c, t)
        @stars.each do |x, y, ph, sp|
          f = ((t * sp + ph) % 1.0)
          next if f > 0.5
          k = 1 - (f - 0.25).abs * 4
          c.put(x, y, k > 0.7 ? "+" : ".", Color.mix([40, 40, 70], [200, 200, 255], k))
        end
      end

      def flash(c, t)
        return if ctx.config.flash == :off
        [[T::DROP, 0.12, [255, 255, 255]], [T.score_land, 0.18, [255, 230, 150]], [T.rank, 0.12, Color.ramp(@rpal, 0.2)]].each do |at, len, col|
          age = t - at
          c.tint_bg(col, 0.55 * (1 - age / len)) if age >= 0 && age < len
        end
      end

      def draw_title(c, t)
        drop = t < T::DROP ? ((1 - Fx.ease_in(t / T::DROP)) * 8).round : 0
        sweep = (t * 0.9) % 1.4 - 0.2
        fn = lambda do |_rx, ry, f|
          base = Color.rainbow(f * 0.7 - t * 0.5 + ry * 0.03, 0.75)
          d = (f - sweep).abs
          d < 0.06 ? Color.mix([255, 255, 255], base, d / 0.06) : base
        end
        Fx.big_text(c, "RESULT", (@w - Font.width("RESULT", scale: @tscale)) / 2, 1 - drop, fn, scale: @tscale)
        Fx.shockwave(c, @w / 2.0, 3.5, t - T::DROP, speed: 110, palette: Color::GOLD, life: 0.6, rings: 3)
      end

      def draw_table(c, t)
        rows_data.each_with_index do |(k, v), i|
          st = T.row_start(i)
          next if t < st
          y = @table_y + i
          slide = Fx.ease_out((t - st) / T::SLIDE)
          p = Fx.phase(t, st + T::SLIDE, T.row_land(i))
          landed = t >= T.row_land(i)
          lx = @table_x - ((1 - slide) * 20).round
          vx = @table_x + 14 + ((1 - slide) * 30).round
          age = t - T.row_land(i)
          c.tint_bg([255, 200, 90], 0.45 * (1 - age / 0.25), @table_x - 1, y, 34, 1) if age >= 0 && age < 0.25
          c.put(lx, y, k.ljust(14, "."), [150, 150, 175])
          shown = k == "TIME" ? clock(v * Fx.ease_out(p)) : Fx.number_with_commas((v * Fx.ease_out(p)).round)
          col = if !landed then [255, 255, 255]
                elsif k == "ERRORS" || k == "INTERRUPTS" then [180, 190, 220]
                else Color.ramp(Color::GOLD, 0.2)
                end
          c.put(vx, y, shown.rjust(16), col, bold: true)
        end
      end

      def draw_score(c, t)
        return if t < T.score_start
        p = Fx.phase(t, T.score_start, T.score_land)
        landed = t >= T.score_land
        val = landed ? @score : (@score * Fx.ease_in(p) ** 0.7).round
        txt = Fx.number_with_commas(val)
        unless @big_score
          c.put_center(@table_y + T::ROWS + 1, "TOTAL SCORE  #{txt}", landed ? Color.rainbow(t) : [150, 220, 255], bold: true)
          return
        end
        c.put_center(@score_y - 1, "T O T A L   S C O R E", [170, 170, 200], bold: true)
        scale = Font.width(Fx.number_with_commas(@score), scale: 2) <= @w - 4 ? 2 : 1
        scale = 1 if Font.width(txt, scale: scale) > @w - 2
        fn = lambda do |_rx, ry, f|
          if landed
            base = Color.ramp(Color::GOLD, 0.1 + ry * 0.12)
            sweep = ((t - T.score_land) * 1.5) % 1.4 - 0.2
            d = (f - sweep).abs
            d < 0.08 ? Color.mix([255, 255, 255], base, d / 0.08) : base
          else
            Color.ramp(Color::ICE, 0.15 + ry * 0.1)
          end
        end
        jitter = landed ? 0 : @rng.rand(2)
        Fx.big_text(c, txt, (@w - Font.width(txt, scale: scale)) / 2 + jitter, @score_y, fn, scale: scale)
        Fx.shockwave(c, @w / 2.0, @score_y + 2.5, t - T.score_land, speed: 140, palette: Color::GOLD, life: 0.7, rings: 4)
      end

      def draw_rank(c, t)
        if @panel.nil?
          return if t < T.rank
          c.put_center(@big_score ? @score_y - 3 : @table_y + T::ROWS + 3, "RANK #{@rank}   #{@title}", Color.ramp(@rpal, 0.15), bold: true)
          return
        end
        px, py, pw, ph = @panel
        return if t < T.rank - 0.14
        if t < T.rank
          grow = ((1 - Fx.ease_in((t - T.rank + 0.14) / 0.14)) * 8).round
          c.fill_bg(Color.scale(Color.ramp(@rpal, 0.5), 0.35), px - grow, py - grow / 2, pw + grow * 2, ph + grow)
          return
        end
        c.fill_bg(Color.scale(Color.ramp(@rpal, 0.6), 0.45), px, py, pw, ph)
        c.fill_bg([12, 12, 22], px + 1, py + 1, pw - 2, ph - 2)
        c.put(px + (pw - 4) / 2, py + 1, "RANK", [200, 200, 220], bold: true)
        lw = Font.width(@rank, scale: 2)
        fn = lambda do |_rx, ry, f|
          @rank == "S" ? Color.rainbow(f * 0.5 - t + ry * 0.05) : Color.ramp(@rpal, 0.05 + ry * 0.1)
        end
        Fx.big_text(c, @rank, px + (pw - lw) / 2, py + 2, fn, scale: 2)
        n = (@title.size * Fx.phase(t, T.rank + 0.15, T.rank + 0.5)).round
        c.put(px + (pw - @title.size) / 2, py + 7, @title[0, n], Color.ramp(@rpal, 0.1), bold: true)
      end

      def draw_footer(c, t)
        msg = "thanks for playing  #{Term.glyph('✦', '*')}  see you next session"
        n = (msg.size * Fx.phase(t, T.rank + 0.9, T.rank + 1.5)).round
        c.put_center(@h - 1, msg[0, n], [170, 170, 200]) if n > 0
      end

      def clock(sec)
        sec = sec.to_i
        h, rest = sec.divmod(3600)
        m, s = rest.divmod(60)
        h > 0 ? format("%dh%02dm%02ds", h, m, s) : format("%dm%02ds", m, s)
      end
    end
  end
end
