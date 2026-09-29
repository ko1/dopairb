# frozen_string_literal: true

module Dopairb
  # Drawing primitives shared by scenes and the input lane. All motion is a
  # closed-form function of time so frames can be sampled at any rate.
  module Fx
    Particle = Struct.new(:x, :y, :vx, :vy, :born, :life, :palette, :glyph, :gravity, :drag)

    class Particles
      attr_reader :list

      def initialize(rng = Random.new)
        @rng = rng
        @list = []
      end

      def clear = @list.clear
      def empty? = @list.empty?

      # speed in cells/sec; y velocity is squashed to respect the cell aspect
      def burst(x, y, n, at:, speed: 20.0, spread: 1.0, life: 0.6, palette: Color::FIRE, glyphs: nil,
                gravity: 18.0, angle: nil, arc: Math::PI * 2, drag: 1.5)
        n.times do
          a = angle ? angle + (@rng.rand - 0.5) * arc : @rng.rand * Math::PI * 2
          s = speed * (0.35 + @rng.rand * 0.65 * spread)
          g = glyphs && glyphs[@rng.rand(glyphs.size)]
          @list << Particle.new(x, y, Math.cos(a) * s, Math.sin(a) * s * 0.5, at, life * (0.6 + @rng.rand * 0.4),
                                palette, g, gravity, drag)
        end
        self
      end

      def add(x, y, vx, vy, at:, life:, palette:, glyph: nil, gravity: 0.0, drag: 0.0)
        @list << Particle.new(x, y, vx, vy, at, life, palette, glyph, gravity, drag)
      end

      def prune(t)
        @list.reject! { |p| t - p.born > p.life }
      end

      def alive?(t)
        @list.any? { |p| t - p.born <= p.life }
      end

      def draw(canvas, t)
        @list.each do |p|
          age = t - p.born
          next if age < 0 || age > p.life
          x, y = position(p, age)
          col = Color.ramp(p.palette, age / p.life)
          if p.glyph
            canvas.put(x, y, p.glyph, col, bold: age < p.life * 0.3)
          else
            canvas.dot(x * 2, y * 4, col)
          end
        end
      end

      def position(p, age)
        if p.drag > 0
          k = (1 - Math.exp(-p.drag * age)) / p.drag
          [p.x + p.vx * k, p.y + p.vy * k + 0.5 * p.gravity * age * age * 0.25]
        else
          [p.x + p.vx * age, p.y + p.vy * age + 0.5 * p.gravity * age * age * 0.25]
        end
      end
    end

    module_function

    def ease_out(t) = 1 - (1 - clamp01(t))**3
    def ease_in(t) = clamp01(t)**3
    def ease_out_back(t)
      t = clamp01(t)
      c1 = 1.70158
      c3 = c1 + 1
      1 + c3 * (t - 1)**3 + c1 * (t - 1)**2
    end

    def clamp01(t) = t < 0 ? 0.0 : (t > 1 ? 1.0 : t.to_f)

    def phase(t, from, to)
      clamp01((t - from) / (to - from))
    end

    def pixel_char
      Term.glyph("█", "⣿", "#")
    end

    # Big bitmap text. color_fn.(x, y, i) -> rgb where i is the pixel column.
    # scale doubles pixels horizontally for chunkier letters.
    def big_text(canvas, text, x, y, color_fn, scale: 1, glitch: 0.0, rng: nil, reveal: 1.0, bg_fn: nil)
      bm = Font.bitmap(text)
      pc = pixel_char
      width = bm[0].size
      shown = (width * reveal).ceil
      bm.each_with_index do |row, ry|
        row.each_with_index do |on, rx|
          next unless on
          next if rx >= shown
          ox = 0
          if glitch > 0 && rng && rng.rand < glitch
            ox = rng.rand(5) - 2
          end
          col = color_fn.(rx, ry, rx.fdiv([width - 1, 1].max))
          scale.times do |s|
            canvas.put(x + rx * scale + s + ox, y + ry, pc, col, bg: bg_fn&.(rx, ry))
          end
        end
      end
      width * scale
    end

    def text_fits?(text, w, scale = 1)
      Font.width(text, scale: scale) <= w
    end

    # Largest scale (2, 1) that fits; nil if the big font does not fit at all.
    def best_scale(text, w)
      return 2 if text_fits?(text, w, 2) && Font.width(text, scale: 2) <= 110
      return 1 if text_fits?(text, w, 1)
      nil
    end

    def shockwave(canvas, cx, cy, age, speed: 40.0, palette: Color::GOLD, life: 0.5, rings: 2)
      return if age < 0 || age > life
      rings.times do |i|
        a = age - i * 0.06
        next if a < 0
        canvas.ring(cx, cy, a * speed, Color.ramp(palette, a / life), density: 1.3)
      end
    end

    def sparkles(canvas, t, rng_seed, count, palette: Color::GOLD, area: nil)
      x0, y0, w, h = area || [0, 0, canvas.w, canvas.h]
      r = Random.new(rng_seed)
      stars = [Term.glyph("✦", "*"), Term.glyph("✧", "+"), "*", "+", "."]
      count.times do |i|
        px = x0 + r.rand(w)
        py = y0 + r.rand(h)
        period = 0.25 + r.rand * 0.5
        ph = ((t + r.rand) / period) % 1.0
        next if ph > 0.6
        canvas.put(px, py, stars[i % stars.size], Color.ramp(palette, ph / 0.6), bold: ph < 0.2)
      end
    end

    def number_with_commas(n)
      s = n.abs.to_s
      s = s.reverse.scan(/\d{1,3}/).join(",").reverse
      n < 0 ? "-#{s}" : s
    end
  end
end
