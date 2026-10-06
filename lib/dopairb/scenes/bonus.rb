# frozen_string_literal: true

module Dopairb
  module Scenes
    # A random critical hit: a slash, a red flash and the multiplier punching in.
    class Critical < Scene
      def top? = !ctx.input.nil?
      def big? = true
      def height = 3
      def length = 0.7
      def sfx = :crit
      def impact_at = 0.1
      def flash_at = 0.1

      def setup
        @x = 4
        @parts = Fx::Particles.new(@rng)
        @parts.burst(@x + 6, 1.5, 34, at: 0.1, speed: 42, life: 0.4, palette: Color::BLOOD, gravity: 8)
        @parts.burst(@x + 6, 1.5, 16, at: 0.12, speed: 26, life: 0.35, palette: Color::GOLD, gravity: 6,
                                      glyphs: ["*", "+", Term.glyph("✦", "*")])
      end

      def shake(t) = t.between?(0.1, 0.22) ? (@rng.rand(3) - 1) * 2 : 0

      def draw(c, t)
        if t < 0.1
          p = t / 0.1
          (0..2).each do |y|
            x = (@x - 2 + p * 16 + y * 3).round
            c.put(x, y, "\\", [255, 255, 255], bold: true)
            c.put(x - 1, y, "\\", [255, 120, 120])
          end
          return
        end
        @parts.draw(c, t)
        p = Fx.phase(t, 0.1, 0.7)
        c.tint_bg([255, 40, 40], 0.5 * (1 - Fx.phase(t, 0.1, 0.22)), 0, 0, @w, 3) if ctx.config.flash != :off
        label = "CRITICAL!!"
        label.each_char.with_index do |ch, i|
          flick = ((t * 20).to_i + i).even?
          col = flick ? [255, 70, 60] : [255, 220, 90]
          c.put(@x + i, 1, ch, t < 0.16 ? [255, 255, 255] : col, bold: true)
        end
        mx = @x + label.size + 2
        m = " x#{event.mult} "
        pop = Fx.ease_out_back(Fx.phase(t, 0.12, 0.3))
        bg = Color.mix([255, 255, 255], [200, 30, 30], pop)
        c.put(mx, 1, m, [255, 255, 255], bg: bg, bold: true) if pop > 0.05
        c.put(mx + m.size + 2, 1, "+#{Fx.number_with_commas(event.gain)}", Color.mix([255, 255, 255], [255, 210, 90], p), bold: true)
        sub = sub_bits.reject { |b| b.start_with?("+", "CRITICAL") }.join("   ")
        c.put(@x, 2, sub, [170, 150, 150]) if p > 0.2 && !sub.empty?
        c.put(@x, 0, "=>", [255, 160, 160], bold: true)
      end

      def trail
        paint("=> #{Term.glyph('✦', '*')} CRITICAL!! x#{event.mult}  +#{Fx.number_with_commas(event.gain)}" +
              (event.combo > 1 ? "  COMBO #{event.combo}" : ""), [255, 110, 90], bold: true)
      end
    end

    # The rare jackpot: three slot reels stop on 7-7-7, then coins rain.
    class Jackpot < Scene
      SYMBOLS = %w[7 $ ? ! * #].freeze
      STOPS = [0.45, 0.7, 0.95].freeze
      REEL_W = 9

      def top? = !ctx.input.nil?
      def big? = true
      def mega? = true
      def length = 2.3
      def sfx = :jackpot
      def impact_at = STOPS.last
      def flash_at = STOPS.last
      def height = @full ? 10 : 2

      def setup
        @full = !ctx.compact && @w >= REEL_W * 3 + 8
        @x0 = (@w - (REEL_W * 3 + 4)) / 2
        @parts = Fx::Particles.new(@rng)
        @coins = Fx::Particles.new(@rng)
        return unless @full
        STOPS.each_with_index do |at, i|
          @parts.burst(@x0 + i * (REEL_W + 2) + REEL_W / 2.0, 3.5, 14, at: at, speed: 22, life: 0.3, palette: Color::GOLD, gravity: 6)
        end
        @parts.burst(@w / 2.0, 3.5, 90, at: STOPS.last, speed: 70, life: 0.7, palette: Color::GOLD, gravity: 14)
        70.times do
          @coins.add(@rng.rand * @w, -1, (@rng.rand - 0.5) * 6, 6 + @rng.rand * 8, at: STOPS.last + @rng.rand * 1.1, life: 1.1,
                                         palette: [[255, 250, 200], [255, 210, 60], [200, 140, 0]],
                                         glyph: ["$", "o", "O", "$", Term.glyph("✦", "*")][@rng.rand(5)], gravity: 6)
        end
      end

      def shake(t) = (t - STOPS.last).between?(0, 0.35) ? ((@rng.rand * 2 - 1) * 3 * (1 - (t - STOPS.last) / 0.35)).round : 0

      def draw(c, t)
        return draw_compact(c, t) unless @full
        c.fill_bg([60, 20, 70], @x0 - 2, 0, REEL_W * 3 + 8, 7)
        lights = (t * 12).to_i
        (REEL_W * 3 + 8).times do |i|
          on = (i + lights).even?
          c.put(@x0 - 2 + i, 0, "o", on ? [255, 230, 120] : [120, 80, 40], bg: [60, 20, 70], bold: on)
          c.put(@x0 - 2 + i, 6, "o", on ? [120, 80, 40] : [255, 230, 120], bg: [60, 20, 70], bold: !on)
        end
        3.times do |i|
          x = @x0 + i * (REEL_W + 2)
          c.fill_bg([250, 245, 235], x, 1, REEL_W, 5)
          stopped = t >= STOPS[i]
          sym = stopped ? "7" : SYMBOLS[((t * 26).to_i + i * 2) % SYMBOLS.size]
          bounce = stopped && t - STOPS[i] < 0.06 ? 1 : 0
          col = if stopped
                  t >= STOPS.last ? Color.rainbow(t * 1.5 + i * 0.2) : [220, 30, 40]
                else
                  [140, 140, 160]
                end
          gw = Font.width(sym)
          Fx.big_text(c, sym, x + (REEL_W - gw) / 2, 1 + bounce, ->(*) { col }, bg_fn: ->(*) { [250, 245, 235] })
          c.tint_bg([0, 0, 0], 0.25, x, 1, REEL_W, 5) unless stopped
        end
        @parts.draw(c, t)
        @coins.draw(c, t)
        return if t < STOPS.last
        c.tint_bg([255, 230, 120], 0.6 * (1 - Fx.phase(t, STOPS.last, STOPS.last + 0.15)), 0, 0, @w, height) if ctx.config.flash != :off
        label = "J A C K P O T !!   x#{event.mult}"
        n = (label.size * Fx.phase(t, STOPS.last, STOPS.last + 0.3)).round
        label[0, n].each_char.with_index do |ch, i|
          c.put((@w - label.size) / 2 + i, 8, ch, Color.rainbow(i / 14.0 - t), bold: true)
        end
        gain = (event.gain * Fx.ease_out(Fx.phase(t, STOPS.last + 0.1, STOPS.last + 0.7))).round
        c.put_center(9, "+#{Fx.number_with_commas(gain)}  #{sub_bits.reject { |b| b.start_with?('+', 'JACKPOT') }.join('   ')}",
                     [255, 220, 120], bold: true)
      end

      def draw_compact(c, t)
        3.times do |i|
          sym = t >= STOPS[i] ? "7" : SYMBOLS[((t * 26).to_i + i) % SYMBOLS.size]
          c.put(1 + i * 4, 0, "[#{sym}]", t >= STOPS[i] ? [255, 80, 80] : [180, 180, 190], bold: true)
        end
        c.put(1, 1, "JACKPOT!! x#{event.mult}  +#{Fx.number_with_commas(event.gain)}", Color.rainbow(t), bold: true) if t >= STOPS.last
      end

      def trail
        s = "#{Term.glyph('✦', '*')} [7][7][7] JACKPOT!! x#{event.mult}  +#{Fx.number_with_commas(event.gain)}"
        return s if depth == :none
        s.each_char.with_index.map { |ch, i| "#{Color.sgr(Color.rainbow(i / 20.0), nil, true, depth)}#{ch}" }.join + "\e[0m"
      end
    end

    # LEVEL UP: the title slams in, then a masterpiece is unveiled full screen.
    class Masterpiece < Scene
      LAND = 0.22
      REVEAL = 1.0
      SHOWN = 1.75

      def self.fits?(rows, cols) = rows >= 16 && cols >= 40

      def alt? = true
      def big? = true
      def mega? = true
      def height = ctx.rows
      def length = 4.2
      def sfx = :levelup
      def impact_at = LAND
      def flash_at = LAND

      def setup
        @h = ctx.rows
        @piece = Gallery.find(event.info[:art]) || Gallery::PIECES.first
        @title = "LEVEL UP!"
        @tscale = Font.width(@title, scale: 2) <= @w - 4 ? 2 : 1
        @aw, @ah = Gallery.fit(@piece, @w - 6, @h - 6)
        @ax = (@w - @aw) / 2
        @ay = 2
        @parts = Fx::Particles.new(@rng)
        tw = Font.width(@title, scale: @tscale)
        cy = @h / 2.0 - 1
        10.times do |i|
          @parts.burst((@w - tw) / 2.0 + tw * i / 9.0, cy + 3, 9, at: LAND, speed: 45, life: 0.6, palette: Color::NEON, gravity: 18,
                                                             angle: -Math::PI / 2, arc: Math::PI * 1.6)
        end
        @parts.burst(@w / 2.0, @ay + @ah / 4.0, 120, at: REVEAL + 0.45, speed: 80, life: 0.8, palette: Color::GOLD, gravity: 10)
        @stars = Array.new(60) { [@rng.rand(@w), @rng.rand(@h), @rng.rand, 0.5 + @rng.rand] }
      end

      def shake(t)
        [[LAND, 4, 0.35], [REVEAL + 0.45, 2, 0.25]].each do |at, amp, len|
          age = t - at
          return ((@rng.rand * 2 - 1) * amp * (1 - age / len)).round if age >= 0 && age < len
        end
        0
      end

      def draw(c, t)
        draw_stars(c, t)
        t < REVEAL ? draw_title(c, t) : draw_art(c, t)
        @parts.draw(c, t)
      end

      def trail
        star = Term.glyph("✦", "*")
        g = event.info[:gallery]
        s = "#{star} LEVEL UP! LV #{event.level} #{star}  BONUS ART: #{@piece.title} (#{@piece.artist}, #{@piece.year})"
        s << (event.info[:art_new] ? "  NEW!" : "  ENCORE")
        s << "  GALLERY #{g[0]}/#{g[1]}" if g
        paint(s, Color.ramp(Color::NEON, 0.15), bold: true)
      end

      private

      def draw_stars(c, t)
        @stars.each do |x, y, ph, sp|
          f = (t * sp + ph) % 1.0
          next if f > 0.5
          k = 1 - (f - 0.25).abs * 4
          c.put(x, y, k > 0.7 ? "+" : ".", Color.mix([40, 30, 70], [220, 200, 255], k))
        end
      end

      def draw_title(c, t)
        y0 = (@h - Font::HEIGHT) / 2 - 1
        drop = t < LAND ? ((1 - Fx.ease_in(t / LAND)) * (y0 + 6)).round : 0
        sweep = (t * 1.4) % 1.4 - 0.2
        fn = lambda do |_rx, ry, f|
          base = Color.rainbow(f * 0.8 - t + ry * 0.03, 0.8)
          (f - sweep).abs < 0.07 && t >= LAND ? [255, 255, 255] : base
        end
        Fx.big_text(c, @title, (@w - Font.width(@title, scale: @tscale)) / 2, y0 - drop, fn, scale: @tscale)
        return if t < LAND
        c.tint_bg([200, 120, 255], 0.55 * (1 - Fx.phase(t, LAND, LAND + 0.15))) if ctx.config.flash != :off
        Fx.shockwave(c, @w / 2.0, y0 + 2.5, t - LAND, speed: 110, palette: Color::NEON, life: 0.6, rings: 3)
        lv = "LV #{event.level - 1}  >>  LV #{event.level}"
        n = (lv.size * Fx.phase(t, LAND + 0.1, LAND + 0.4)).round
        c.put_center(y0 + Font::HEIGHT + 2, lv[0, n], [255, 230, 140], bold: true)
        msg = "BONUS ART UNLOCKED"
        c.put_center(y0 + Font::HEIGHT + 4, msg, ((t * 8).to_i.even? ? [255, 255, 255] : [255, 200, 90]), bold: true) if t > LAND + 0.45
      end

      def draw_art(c, t)
        p = Fx.phase(t, REVEAL, REVEAL + 0.45)
        rows = @ah / 2
        # gold frame
        frame = Color.mix([255, 240, 170], [190, 130, 30], (Math.sin(t * 6) + 1) / 2)
        c.fill_bg(frame, @ax - 2, @ay - 1, @aw + 4, rows + 2)
        c.fill_bg([70, 45, 10], @ax - 1, @ay, @aw + 2, rows) if p < 1
        head = rows * p
        sheen = (t - REVEAL - 0.5) * 1.2
        Gallery.draw(c, @piece, @ax, @ay, @aw, @ah, reveal: p, depth: depth) do |top, bot, x, r|
          if p < 1 && (r - head).abs < 1.2
            [Color.mix(top, [255, 255, 255], 0.8), Color.mix(bot, [255, 255, 255], 0.8)]
          elsif sheen.between?(0, 1.5) && ((x.fdiv(@aw) + r.fdiv(rows) * 0.5) - sheen).abs < 0.06
            [Color.mix(top, [255, 255, 255], 0.55), Color.mix(bot, [255, 255, 255], 0.55)]
          else
            [top, bot]
          end
        end
        Fx.sparkles(c, t, 21, 18, palette: Color::GOLD, area: [@ax - 4, @ay - 1, @aw + 8, rows + 2]) if p >= 1
        c.put_center(0, "#{Term.glyph('✦', '*')}  LEVEL #{event.level}  #{Term.glyph('✦', '*')}  BONUS ART", Color.rainbow(t * 0.7), bold: true)
        return if t < REVEAL + 0.45
        cap = "\"#{@piece.title}\"  #{@piece.artist}, #{@piece.year}"
        n = (cap.size * Fx.phase(t, REVEAL + 0.5, REVEAL + 1.0)).round
        c.put_center(@ay + rows + 1, cap[0, n], [240, 230, 210], bold: true)
        g = event.info[:gallery]
        tag = event.info[:art_new] ? "NEW!" : "ENCORE"
        tag += "   GALLERY #{g[0]}/#{g[1]}" if g
        if t > REVEAL + 0.9
          col = event.info[:art_new] && (t * 6).to_i.even? ? [255, 90, 90] : [255, 220, 120]
          c.put_center(@ay + rows + 2, tag, col, bold: true)
        end
      end
    end
  end
end
