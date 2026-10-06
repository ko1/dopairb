# frozen_string_literal: true

module Dopairb
  module Scenes
    # Ordinary value: a comet leaves "=>" and lands with a small burst.
    class Hit < Scene
      def top? = !ctx.input.nil?
      def length = 0.42
      def sfx = :hit
      def impact_at = 0.16

      def setup
        @target = [[@w - 30, 34].min, 8].max
        @parts = Fx::Particles.new(@rng)
        pal = combo_palette
        @parts.burst(@target, 0.5, 14 + [event.combo, 20].min, at: 0.16, speed: 26, life: 0.28, palette: pal,
                                                                gravity: 3, angle: 0, arc: Math::PI * 2)
      end

      def draw(c, t)
        pal = combo_palette
        hot = t < 0.3 ? Color.mix([255, 255, 255], Color.ramp(pal, 0.2), t / 0.3) : Color.ramp(pal, 0.4)
        c.put(0, 0, "=>", hot, bold: true)
        if t < 0.16
          head = 3 + (@target - 3) * Fx.ease_in(t / 0.16)
          fever = event.flag?(:fever)
          9.times do |i|
            x = head - i
            break if x < 3
            col = fever ? Color.rainbow(i / 9.0 - t * 4) : Color.ramp(pal, i / 9.0)
            c.put(x, 0, i.zero? ? Term.glyph("✦", "*") : (i < 3 ? "=" : "-"), col, bold: i < 2)
          end
        else
          p = Fx.phase(t, 0.16, 0.42)
          @parts.draw(c, t)
          txt = "+#{Fx.number_with_commas(event.gain)}"
          col = Color.mix([255, 255, 255], Color.ramp(pal, 0.3), p)
          x = c.put(@target + 2, 0, txt, col, bg: p < 0.25 ? Color.ramp(pal, 0.6) : nil, bold: true)
          x = c.put(x + 2, 0, "COMBO #{event.combo}", combo_color(t), bold: event.combo >= 5) if event.combo > 1
          if event.flag?(:fever) && x
            " FEVER x2 ".each_char.with_index do |ch, i|
              x = c.put(x + (i.zero? ? 2 : 0), 0, ch, [20, 10, 30], bg: Color.rainbow(i / 10.0 - t * 2), bold: true)
            end
          end
        end
      end

      def trail
        paint("=> #{Term.glyph('✦', '*')} +#{Fx.number_with_commas(event.gain)}" + (event.combo > 1 ? "  COMBO #{event.combo}" : "") +
              (event.flag?(:fever) ? "  FEVER x2" : ""), combo_color)
      end
    end

    # nil: a swing and a miss, then smoke.
    class Puff < Scene
      def top? = !ctx.input.nil?
      def length = 0.5
      def sfx = :puff
      def impact_at = 0.12

      def setup
        @parts = Fx::Particles.new(@rng)
        18.times do
          @parts.add(12 + @rng.rand * 6, 0.9, (@rng.rand - 0.3) * 10, -1.5 - @rng.rand * 2.5,
                     at: 0.12 + @rng.rand * 0.08, life: 0.35, palette: Color::SMOKE)
        end
      end

      def draw(c, t)
        c.put(0, 0, "=>", [160, 160, 170], bold: true)
        if t < 0.12
          x = 3 + 14 * Fx.ease_out(t / 0.12)
          c.put(x - 3, 0, "~~~", [200, 200, 210])
        else
          @parts.draw(c, t)
          p = Fx.phase(t, 0.12, 0.5)
          c.put(22, 0, "nil", Color.mix([230, 230, 230], [90, 90, 100], p))
          c.put(27, 0, "whiff...", Color.mix([150, 150, 160], [60, 60, 70], p)) if p > 0.2
        end
      end
    end

    # true / false: an ink stamp slams down.
    class Stamp < Scene
      def sfx = :stamp
      def height = 3
      def length = 0.6
      def top? = !ctx.input.nil?

      def setup
        @yes = event.info[:type] == :true
        @label = @yes ? "YES!" : "NO!"
        @ink = @yes ? [30, 190, 90] : [220, 40, 60]
        @x = 4
        @bw = 12
        @parts = Fx::Particles.new(@rng)
        @parts.burst(@x + @bw / 2.0, 1.5, 26, at: 0.14, speed: 30, life: 0.35,
                                              palette: [Color.mix(@ink, [255, 255, 255], 0.6), @ink, Color.scale(@ink, 0.3)], gravity: 10)
      end

      def shake(t) = t.between?(0.14, 0.24) ? (@rng.rand(3) - 1) : 0
      def flash_at = 0.14

      def draw(c, t)
        if t < 0.14
          p = Fx.ease_in(t / 0.14)
          grow = ((1 - p) * 10).round
          c.fill_bg(Color.scale(@ink, 0.25 + 0.5 * p), @x - grow, 0 - (grow > 4 ? 0 : 0), @bw + grow * 2, 3)
          c.put(@x + (@bw - @label.size) / 2, 1, @label, [255, 255, 255], bold: true) if p > 0.6
        else
          p = Fx.phase(t, 0.14, 0.6)
          @parts.draw(c, t)
          edge = Color.scale(@ink, 0.55)
          c.fill_bg(edge, @x, 0, @bw, 3)
          c.fill_bg(t < 0.2 ? Color.mix(@ink, [255, 255, 255], 0.6) : @ink, @x + 1, 1, @bw - 2, 1)
          c.put(@x + (@bw - @label.size) / 2, 1, @label, [255, 255, 255], bold: true)
          c.put(@x + @bw + 3, 1, @yes ? "true" : "false", Color.mix([255, 255, 255], @ink, p), bold: true)
          c.put(@x + @bw + 10, 1, sub_line, [150, 150, 160]) if p > 0.3 && event.combo > 1
        end
      end

      def trail = paint("[ #{@label} ]", @ink, bold: true)
    end

    # Integers that deserve it: count up in giant digits, then a shockwave.
    class Counter < Scene
      def sfx = :counter
      def big? = true
      def top? = !ctx.input.nil?
      def length = 1.0

      def setup
        @value = event.info[:value]
        @int = Integer === @value
        @final = @int ? Fx.number_with_commas(@value) : format_float(@value)
        @scale = best_scale(@final)
        @parts = Fx::Particles.new(@rng)
        cx = @w / 2.0
        @parts.burst(cx, 3, 60, at: 0.55, speed: 55, life: 0.5, palette: Color::GOLD, gravity: 14)
        @parts.burst(cx, 3, 20, at: 0.58, speed: 30, life: 0.45, palette: Color::FIRE, gravity: 8,
                                glyphs: ["*", "+", "'", "."])
      end

      def height = @scale ? 7 : 3

      def shake(t) = t.between?(0.55, 0.7) ? (@rng.rand(5) - 2) : 0
      def flash_at = 0.55

      def draw(c, t)
        p = Fx.phase(t, 0, 0.55)
        shown = if p >= 1 then @final
                elsif @int then Fx.number_with_commas((@value * Fx.ease_out(p)).to_i)
                else format_float(@value * Fx.ease_out(p))
                end
        landed = t >= 0.55
        shimmer = (t * 1.6) % 1.0
        if @scale
          x = (@w - Font.width(shown, scale: @scale)) / 2
          fn = lambda do |_rx, ry, f|
            base = landed ? Color.ramp(Color::GOLD, 0.15 + ry * 0.12) : Color.ramp(Color::ICE, 0.2 + ry * 0.1)
            d = (f - shimmer).abs
            d < 0.08 ? Color.mix([255, 255, 255], base, d / 0.08) : base
          end
          Fx.big_text(c, shown, x, 1, fn, scale: @scale)
          Fx.shockwave(c, @w / 2.0, 3, t - 0.55, speed: 70, life: 0.45)
          @parts.draw(c, t)
          c.tint_bg([255, 220, 120], 0.35 * (1 - Fx.phase(t, 0.55, 0.7)), 0, 0, @w, 7) if landed && t < 0.7 && ctx.config.flash != :off
          if landed
            sub = sub_line([digits_label])
            c.put_center(6, sub, Color.ramp(Color::GOLD, 0.2), bold: true)
          end
        else
          c.put(2, 1, "=> ", [255, 220, 120], bold: true)
          c.put(5, 1, shown, landed ? [255, 230, 120] : [140, 220, 255], bold: true)
          @parts.draw(c, t)
          c.put(8 + shown.size, 1, sub_line([digits_label]), [220, 200, 150]) if landed
        end
      end

      def digits_label
        if @int
          "#{@value.abs.to_s.size} DIGITS"
        else
          "FLOAT"
        end
      end

      def trail = paint("#{Term.glyph('✦', '*')} #{@final}  #{sub_line([digits_label])}", [255, 210, 90], bold: true)

      private

      def format_float(f)
        return f.to_s unless f.finite?
        f.abs >= 1e15 ? format("%.3e", f) : format("%.3f", f).sub(/\.?0+\z/, "")
      end
    end

    # Long strings: characters pour in while the length counts up.
    class Stream < Scene
      def sfx = :hit
      def height = 2
      def length = 0.75
      def top? = !ctx.input.nil?

      def draw(c, t)
        len = event.info[:length]
        p = Fx.phase(t, 0, 0.5)
        c.put(0, 0, "STRING", [255, 140, 220], bold: true)
        c.put(8, 0, "#{Fx.number_with_commas((len * Fx.ease_out(p)).round)} chars", [255, 255, 255], bold: p >= 1)
        c.put(26, 0, sub_line, [150, 150, 160]) if p >= 1
        head = event.info[:head]
        span = [@w - 4, head.size].min
        span.times do |i|
          arrive = i.fdiv([span, 1].max) * 0.45
          lt = t - arrive
          next if lt < 0
          x = 2 + i + ((@w - i) * (1 - Fx.ease_out(lt / 0.18))).round
          col = lt < 0.12 ? [255, 255, 255] : Color.rainbow(i / 40.0 + t, 0.6)
          c.put(x, 1, head[i], col)
        end
        c.put(2 + span, 1, "...", [120, 120, 130]) if len > span && t > 0.5
      end
    end

    # Arrays and hashes: one block per element pops into place.
    class Crate < Scene
      def sfx = :hit
      def height = 2
      def length = 0.7
      def top? = !ctx.input.nil?

      def draw(c, t)
        hash = event.info[:type] == :hash
        size = event.info[:size]
        label = hash ? "HASH" : "ARRAY"
        cell = hash ? 3 : 2
        fit = [(@w - 14) / cell, 1].max
        n = [size, fit].min
        c.put(0, 0, label, hash ? [255, 200, 90] : [110, 220, 255], bold: true)
        c.put(label.size + 1, 0, "x #{Fx.number_with_commas((size * Fx.ease_out(Fx.phase(t, 0, 0.45))).round)}", [255, 255, 255], bold: true)
        c.put(label.size + 12, 0, sub_line, [150, 150, 160]) if t > 0.45
        n.times do |i|
          born = i.fdiv([n, 1].max) * 0.4
          age = t - born
          next if age < 0
          x = 2 + i * cell
          pop = age < 0.06
          if hash
            c.bg(x, 1, pop ? [255, 255, 255] : Color.hsv(30 + i * 7, 0.7, 0.95))
            c.bg(x + 1, 1, pop ? [255, 255, 255] : Color.hsv(200 + i * 7, 0.6, 0.8))
          else
            c.bg(x, 1, pop ? [255, 255, 255] : Color.hsv(180 + i * 9, 0.65, 0.95))
          end
        end
        c.put(2 + n * cell + 1, 1, "+#{size - n}", [200, 200, 210]) if size > n && t > 0.4
      end
    end

    # Big word banners: FIRST HIT, COMBO 10, NEW RECORD, COMEBACK, milestones.
    class Banner < Scene
      def initialize(ctx, event, text:, sub: nil, palette: Color::FIRE, mega: false, rainbow: false, alt: false)
        @alt = alt
        @text = text
        @sub = sub
        @pal = palette
        @mega = mega
        @rainbow = rainbow
        super(ctx, event)
      end

      def big? = true
      def mega? = @mega
      def alt? = @alt && @mega
      def sfx = @mega ? :mega : :banner
      def top? = !ctx.input.nil? && !@alt
      def length = @mega ? 1.9 : 1.05

      def setup
        @scale = best_scale(@text)
        @scale = 1 if @scale == 2 && !@mega && Font.width(@text, scale: 2) > @w * 0.8
        @land = 0.2
        @parts = Fx::Particles.new(@rng)
        @fire = Fx::Particles.new(@rng)
        return unless @scale
        tw = Font.width(@text, scale: @scale)
        @tx = (@w - tw) / 2
        by = text_y + Font::HEIGHT
        10.times do |i|
          @parts.burst(@tx + tw * i / 9.0, by, @mega ? 10 : 6, at: @land, speed: 40, life: 0.55, palette: @pal,
                                                              gravity: 20, angle: -Math::PI / 2, arc: Math::PI * 1.6)
        end
        return unless @mega
        8.times do |i|
          at = 0.35 + i * 0.16
          x = 4 + @rng.rand * (@w - 8)
          y = 1 + @rng.rand * [height - 6, 2].max
          pal = [Color::FIRE, Color::ICE, Color::NEON, Color::TOXIC, Color::GOLD][i % 5]
          @fire.add(x, height.to_f, 0, -(height - y) / 0.15 * 2, at: at - 0.15, life: 0.15, palette: [[255, 255, 255], [255, 200, 120]])
          @fire.burst(x, y, 45, at: at, speed: 45, life: 0.7, palette: pal, gravity: 10, drag: 2.5)
        end
        40.times do
          @fire.add(@rng.rand * @w, -1, (@rng.rand - 0.5) * 4, 2 + @rng.rand * 4, at: 0.3 + @rng.rand * 1.2, life: 1.2,
                                                                                   palette: [Color.rainbow(@rng.rand), Color.rainbow(@rng.rand)],
                                                                                   glyph: ["*", "+", "'", ",", Term.glyph("✦", "*")][@rng.rand(5)], gravity: 1.5)
        end
      end

      def height
        return ctx.rows if @alt
        return 2 unless @scale
        @mega ? [[ctx.rows - 4, 13].min, 8].max : 7
      end

      def text_y
        @mega ? (height - Font::HEIGHT) / 2 - 1 : 1
      end

      def shake(t)
        return 0 unless t >= @land
        k = 1 - Fx.phase(t, @land, @land + (@mega ? 0.45 : 0.25))
        k > 0 ? ((@rng.rand * 2 - 1) * (@mega ? 4 : 2) * k).round : 0
      end

      def flash_at = @land

      def draw(c, t)
        return draw_compact(c, t) unless @scale
        drop = t < @land ? (1 - Fx.ease_in(t / @land)) * (text_y + Font::HEIGHT + 1) : 0
        y = text_y - drop.round
        sweep = (t * 1.3) % 1.4 - 0.2
        fn = lambda do |_rx, ry, f|
          base = @rainbow ? Color.rainbow(f * 0.8 - t * 0.9) : Color.ramp(@pal, 0.1 + ry * 0.14)
          d = (f - sweep).abs
          t >= @land && d < 0.07 ? Color.mix([255, 255, 255], base, d / 0.07) : base
        end
        @fire.draw(c, t) if @mega
        Fx.big_text(c, @text, @tx, y, fn, scale: @scale)
        if t >= @land
          Fx.shockwave(c, @w / 2.0, text_y + 2.5, t - @land, speed: @mega ? 90 : 60, palette: @pal, life: 0.5, rings: @mega ? 3 : 2)
          @parts.draw(c, t)
          if ctx.config.flash != :off && t < @land + 0.12
            c.tint_bg(Color.ramp(@pal, 0.1), 0.5 * (1 - Fx.phase(t, @land, @land + 0.12)), 0, 0, @w, height)
          end
          Fx.sparkles(c, t, 7, @mega ? 30 : 10, palette: @pal) if t > @land + 0.2
          sub = banner_sub
          n = (sub.size * Fx.phase(t, @land + 0.1, @land + 0.45)).round
          c.put_center(text_y + Font::HEIGHT + (@mega ? 2 : 0), sub[0, n], Color.ramp(@pal, 0.15), bold: true) if n > 0 && text_y + Font::HEIGHT < height
        end
      end

      def banner_sub
        [@sub, *sub_bits.reject { |b| @text.include?(b) }].compact.join("   ")
      end

      def draw_compact(c, t)
        txt = @text.chars.join(" ")
        p = Fx.phase(t, 0, 0.3)
        txt.each_char.with_index do |ch, i|
          col = @rainbow ? Color.rainbow(i / 12.0 - t) : Color.ramp(@pal, (i / [txt.size, 1].max.to_f) * 0.5)
          c.put(1 + i, 0, ch, col, bold: true) if i <= txt.size * p
        end
        c.put(1, 1, banner_sub, Color.ramp(@pal, 0.2)) if t > 0.3
        Fx.sparkles(c, t, 3, 6, palette: @pal)
      end

      def trail
        star = Term.glyph("✦", "*")
        s = +"#{star} #{@text} #{star}"
        sub = banner_sub
        s << "  " << sub unless sub.empty?
        if @rainbow && depth != :none
          s.each_char.with_index.map { |ch, i| "#{Color.sgr(Color.rainbow(i / 20.0), nil, true, depth)}#{ch}" }.join + "\e[0m"
        else
          paint(s, Color.ramp(@pal, 0.15), bold: true)
        end
      end
    end

    # Definitions: a new ability unlocks.
    class Unlock < Banner
      def initialize(ctx, event)
        what = event.info[:what]
        text = { method: "NEW ABILITY", class: "NEW CLASS", module: "NEW MODULE" }[what] || "UNLOCKED"
        super(ctx, event, text: text, palette: Color::NEON)
      end

      def draw(c, t)
        super
        return unless @scale && t >= @land + 0.15
        name = event.info[:name].to_s
        label = "#{event.info[:what] == :method ? 'def' : event.info[:what]} #{name}"
        n = (label.size * Fx.phase(t, @land + 0.15, @land + 0.5)).round
        x = (@w - label.size - 4) / 2
        c.fill_bg([90, 30, 160], x, 6, label.size + 4, 1)
        c.put(x + 2, 6, label[0, n], [255, 255, 255], bold: true)
      end

      def trail
        paint("#{Term.glyph('✦', '*')} #{@text}: #{event.info[:name]}  #{sub_line}", Color.ramp(Color::NEON, 0.2), bold: true)
      end
    end

    # Floods of stdout: digital rain behind a counter.
    class Rain < Scene
      def sfx = :rain
      def height = 5
      def length = 0.9
      def big? = true

      def setup
        @cols = Array.new(@w) { [@rng.rand * 5, 6 + @rng.rand * 14, @rng.rand(3)] }
        @chars = ("0".."9").to_a + ("a".."z").to_a + %w[{ } ( ) < > = ; :]
      end

      def draw(c, t)
        @cols.each_with_index do |(off, speed, kind), x|
          next if kind == 2
          head = (t * speed - off) % (height + 6)
          6.times do |k|
            y = (head - k).floor
            next if y < 0 || y >= height
            ch = @chars[(x * 7 + y * 13 + (t * 20).to_i) % @chars.size]
            col = k.zero? ? [230, 255, 230] : Color.ramp(Color::TOXIC, k / 6.0 + 0.1)
            c.put(x, y, ch, col, bold: k.zero?)
          end
        end
        label = "  OUTPUT RAIN  x#{Fx.number_with_commas(event.info[:out_lines] || 0)} LINES  "
        x = (@w - label.size) / 2
        c.fill_bg([0, 40, 10], x, 2, label.size, 1)
        c.put(x, 2, label, [180, 255, 180], bold: true)
      end

      def trail = paint("#{Term.glyph('✦', '*')} OUTPUT RAIN x#{event.info[:out_lines]} lines", [120, 230, 140], bold: true)
    end
  end
end
