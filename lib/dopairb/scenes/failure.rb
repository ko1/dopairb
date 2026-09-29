# frozen_string_literal: true

module Dopairb
  module Scenes
    # Shared bits for error scenes: red tint on the input, big glitching title.
    class FailureScene < Scene
      def big? = true
      def top? = !ctx.input.nil?
      def pre = 0.0
      def bell? = true

      def title = "FAILED"
      def palette = Color::BLOOD

      def setup
        @scale = best_scale(title)
        @scale = 1 if @scale == 2 && Font.width(title, scale: 2) > @w * 0.7
      end

      def height = @scale ? 7 : 2
      def length = 0.85
      def flash_at = 0.0

      def shake(t) = t < 0.22 ? ((@rng.rand * 2 - 1) * 3 * (1 - t / 0.22)).round : 0

      def draw_top(c, t)
        return nil if t > 0.45
        k = 1 - Fx.phase(t, 0.1, 0.45)
        ox = t < 0.2 ? (@rng.rand(5) - 2) : 0
        ctx.input.plain.each_with_index do |r, y|
          c.put(ox, y, r, Color.mix([220, 220, 225], [255, 70, 80], k), bold: k > 0.5)
        end
        mark_top(c, t)
        true
      end

      def mark_top(_c, _t); end

      def draw(c, t)
        draw_title(c, t)
        draw_detail(c, t)
      end

      def draw_title(c, t)
        if ctx.config.flash != :off && t < 0.1
          c.tint_bg([160, 0, 20], 0.6 * (1 - t / 0.1), 0, 0, @w, height)
        end
        if @scale
          glitch = t < 0.35 ? 0.35 * (1 - t / 0.35) : 0.0
          tear = (t * 17).floor
          fn = lambda do |rx, ry, _f|
            flick = ((rx * 3 + ry * 5 + tear) % 11).zero? && t < 0.4
            flick ? [255, 255, 255] : Color.ramp(palette, 0.15 + ry * 0.12)
          end
          x = (@w - Font.width(title, scale: @scale)) / 2
          Fx.big_text(c, title, x, 0, fn, scale: @scale, glitch: glitch, rng: @rng)
        else
          c.put(1, 0, title.chars.join(" "), Color.ramp(palette, 0.2), bold: true)
        end
      end

      def detail_text
        bits = [event.info[:class_name]]
        bits << "x#{event.streak} in a row" if event.streak > 1
        bits << "combo reset (#{event.info[:broken_combo]})" if event.info[:broken_combo].to_i >= 3
        bits.join("   ")
      end

      def draw_detail(c, t)
        return if t < 0.15
        txt = detail_text
        n = (txt.size * Fx.phase(t, 0.15, 0.45)).round
        y = @scale ? 6 : 1
        c.put_center(y, txt[0, n], [255, 170, 170], bold: true)
      end

      def trail
        s = "#{Term.glyph('✖', 'x')} #{title}"
        s << "  x#{event.streak}" if event.streak > 1
        paint(s, Color.ramp(palette, 0.25), bold: true)
      end
    end

    # SyntaxError: the input line cracks at the error position.
    class Crack < FailureScene
      def title = "SYNTAX BREAK"

      def setup
        super
        @shards = Fx::Particles.new(@rng)
        @pos = ctx.input && event.info[:line] ? ctx.input.locate(event.info[:line] - 1, event.info[:column].to_i) : nil
        @pos ||= ctx.input ? [ctx.input.size - 1, [ctx.input.plain[-1].size, 1].max - 1] : nil
        @path = []
        return unless @pos
        x = @pos[1].to_f
        rows = (ctx.input.size - @pos[0]) + height
        (rows * 4).times do |i|
          x += (@rng.rand - 0.5) * 2.4
          @path << [x, @pos[0] + i / 4.0]
        end
        @shards.burst(@pos[1], 0.3, 24, at: 0.05, speed: 25, life: 0.6, palette: [[255, 255, 255], [255, 80, 80], [90, 20, 30]],
                                                gravity: 22, glyphs: ["/", "\\", "'", ",", "."])
      end

      def mark_top(c, t)
        return unless @pos
        row, x = @pos
        c.bg(x, row, t < 0.3 ? [255, 40, 60] : [120, 20, 30])
        draw_crack(c, t, 0)
      end

      def draw(c, t)
        super
        return unless @pos
        draw_crack(c, t, -ctx.input.size)
        @shards.draw(c, t)
      end

      def detail_text
        d = event.info[:detail]
        loc = event.info[:line] ? "line #{event.info[:line]}:#{event.info[:column].to_i + 1}" : nil
        [loc, d && d[0, [@w - 20, 20].max], ("x#{event.streak} in a row" if event.streak > 1)].compact.join("   ")
      end

      private

      def draw_crack(c, t, yoff)
        n = (@path.size * Fx.phase(t, 0, 0.18)).round
        @path.first(n).each_with_index do |(x, y), i|
          col = Color.mix([255, 255, 255], [255, 60, 70], i.fdiv(@path.size) + Fx.phase(t, 0.2, 0.8))
          c.dot(x * 2, (y + yoff) * 4, col)
        end
      end
    end

    # NameError: the unknown name is put under a spotlight.
    class Spotlight < FailureScene
      def title = "UNKNOWN SYMBOL"
      def palette = [[255, 250, 220], [255, 210, 90], [230, 140, 30], [140, 60, 20], [50, 20, 10]]

      def setup
        super
        @hits = ctx.input ? ctx.input.find(event.info[:name]) : []
      end

      def draw_top(c, t)
        return nil if t > 0.75
        ctx.input.plain.each_with_index { |r, y| c.put(0, y, r, [90, 90, 100]) }
        pulse = 0.5 + 0.5 * Math.sin(t * 30)
        @hits.each do |row, x, wd|
          name = event.info[:name].to_s
          c.put(x, row, name, [20, 10, 0], bg: Color.mix([255, 200, 60], [255, 255, 200], pulse), bold: true) if wd
        end
        true
      end

      def draw(c, t)
        super
        @hits.first(3).each do |_row, x, wd|
          height.times do |y|
            k = (1 - y.fdiv(height)) * 0.45 * (1 - Fx.phase(t, 0.5, 0.85))
            c.tint_bg([255, 220, 120], k, x - y / 2, y, wd + y, 1)
          end
        end
      end

      def detail_text
        n = event.info[:name]
        base = n ? "`#{n}` is not defined here" : event.info[:message].to_s[0, 60]
        [base, ("x#{event.streak} in a row" if event.streak > 1)].compact.join("   ")
      end
    end

    # NoMethodError: the link between receiver and method snaps.
    class Snap < FailureScene
      def title = "NO METHOD"
      def palette = Color::NEON
      def height = 4
      def length = 0.9

      def setup
        super
        @scale = nil
        @left = " #{event.info[:receiver]} "
        @right = " .#{event.info[:name]} "
        @parts = Fx::Particles.new(@rng)
        @mid = @w / 2.0
        @parts.burst(@mid, 1.5, 40, at: 0.28, speed: 30, life: 0.45, palette: [[255, 255, 255], [255, 230, 120], [255, 90, 200], [60, 20, 80]], gravity: 12)
        @hits = ctx.input ? ctx.input.find(event.info[:name]) : []
      end

      def draw_top(c, t)
        return nil if t > 0.6
        ctx.input.plain.each_with_index { |r, y| c.put(0, y, r, [120, 120, 135]) }
        @hits.each { |row, x, _| c.put(x, row, event.info[:name].to_s, [255, 255, 255], bg: [150, 40, 170], bold: true) }
        true
      end

      def draw(c, t)
        gap = t < 0.28 ? 0 : (Fx.ease_out(Fx.phase(t, 0.28, 0.6)) * 8).round
        lx = [(@mid - 14 - gap - @left.size).round, 0].max
        rx = [(@mid + 14 + gap).round, @w - @right.size - 1].min
        c.put(lx, 1, @left, [255, 255, 255], bg: [40, 90, 200], bold: true)
        c.put(rx, 1, @right, [255, 255, 255], bg: [170, 40, 160], bold: true)
        a = lx + @left.size
        b = rx - 1
        if t < 0.28
          reach = a + (b - a) * Fx.ease_out(t / 0.2)
          (a..reach.round).each do |x|
            wob = Math.sin(x * 1.3 + t * 60) * 0.35
            c.dot(x * 2, (1.5 + wob) * 4, Color.mix([150, 220, 255], [255, 255, 255], @rng.rand))
          end
        else
          fall = Fx.phase(t, 0.28, 0.9)
          (a..(@mid - gap / 2.0).round).each { |x| c.dot(x * 2, (1.5 + fall * fall * 2 * ((x - a) / 10.0)) * 4, [120, 170, 220]) }
          ((@mid + gap / 2.0).round..b).each { |x| c.dot(x * 2, (1.5 + fall * fall * 2 * ((b - x) / 10.0)) * 4, [200, 120, 210]) }
          @parts.draw(c, t)
          c.put_center(0, "N O   M E T H O D", Color.ramp(palette, 0.15), bold: true)
          txt = detail_text
          c.put_center(3, txt[0, (txt.size * Fx.phase(t, 0.35, 0.65)).round], [230, 190, 255])
        end
      end

      def detail_text
        [event.info[:message].to_s[0, [@w - 4, 20].max], ("x#{event.streak} in a row" if event.streak > 1)].compact.join("   ")
      end
    end

    # TypeError / ArgumentError: the two sides collide.
    class Clash < FailureScene
      def title = event.info[:type] == :argument ? "ARGUMENT CLASH" : "TYPE CLASH"
      def palette = Color::FIRE
      def length = 0.95

      def setup
        super
        @scale = nil
        l, r = event.info[:sides]
        @l = " #{l} "
        @r = " #{r} "
        @parts = Fx::Particles.new(@rng)
        @cx = @w / 2.0
        @parts.burst(@cx, 2, 70, at: 0.3, speed: 60, life: 0.55, palette: Color::FIRE, gravity: 16)
        @parts.burst(@cx, 2, 16, at: 0.32, speed: 35, life: 0.5, palette: Color::SMOKE, gravity: 4, glyphs: ["*", "#", "%", "@"])
      end

      def height = 5
      def shake(t) = t.between?(0.3, 0.5) ? ((@rng.rand * 2 - 1) * 4 * (1 - Fx.phase(t, 0.3, 0.5))).round : 0
      def flash_at = 0.3

      def draw_top(c, t) = t < 0.3 ? nil : super

      def draw(c, t)
        if t < 0.3
          p = Fx.ease_in(t / 0.3)
          lx = (@cx - @l.size) * p
          rx = @w - @r.size - (@w - @r.size - @cx) * p
          c.put(lx, 2, @l, [255, 255, 255], bg: [30, 120, 220], bold: true)
          c.put(rx, 2, @r, [255, 255, 255], bg: [220, 90, 20], bold: true)
          (0..3).each { |k| c.put(lx - k - 1, 2, "-", Color.scale([30, 120, 220], 1 - k / 4.0)) }
          (0..3).each { |k| c.put(rx + @r.size + k, 2, "-", Color.scale([220, 90, 20], 1 - k / 4.0)) }
        else
          p = Fx.phase(t, 0.3, 0.95)
          back = Fx.ease_out(p) * 10
          c.put(@cx - @l.size - back, 2, @l, Color.mix([255, 255, 255], [90, 90, 100], p), bg: Color.mix([30, 120, 220], [20, 30, 50], p))
          c.put(@cx + back, 2, @r, Color.mix([255, 255, 255], [90, 90, 100], p), bg: Color.mix([220, 90, 20], [50, 25, 10], p))
          Fx.shockwave(c, @cx, 2, t - 0.3, speed: 80, palette: Color::FIRE, life: 0.4, rings: 3)
          @parts.draw(c, t)
          c.tint_bg([255, 200, 120], 0.6 * (1 - Fx.phase(t, 0.3, 0.42)), 0, 0, @w, height) if ctx.config.flash != :off
          c.put_center(0, title.chars.join(" "), Color.ramp(palette, 0.2), bold: true) if t > 0.36
          txt = detail_text
          c.put_center(4, txt[0, (txt.size * Fx.phase(t, 0.4, 0.7)).round], [255, 200, 170]) if t > 0.4
        end
      end

      def detail_text
        [event.info[:message].to_s[0, [@w - 4, 20].max], ("x#{event.streak} in a row" if event.streak > 1)].compact.join("   ")
      end
    end

    # Ctrl-C: the collected charge scatters and fades.
    class Scatter < Scene
      def height = 2
      def length = 0.65
      def big? = true

      def setup
        @parts = Fx::Particles.new(@rng)
        n = [(event.info[:charge].to_f / 4).round, 6].max
        n.times do |i|
          @parts.burst(2 + i, 0.5, 4, at: 0.05, speed: 30, life: 0.5, palette: Color::STEEL, gravity: 6)
        end
      end

      def draw(c, t)
        @parts.draw(c, t)
        word = "INTERRUPTED"
        sp = ((1 - Fx.ease_out(Fx.phase(t, 0, 0.35))) * 3).round + 1
        txt = word.chars.join(" " * sp)
        c.put(2, 1, txt[0, @w - 3], Color.mix([255, 255, 255], [120, 140, 180], Fx.phase(t, 0.1, 0.6)), bold: true)
      end

      def trail = paint("#{Term.glyph('✖', 'x')} INTERRUPTED", [140, 160, 200], bold: true)
    end
  end
end
