# frozen_string_literal: true

module Dopairb
  # RGB helpers and SGR encoding for truecolor / 256 / 16 / no-color terminals.
  module Color
    FIRE  = [[255, 255, 230], [255, 236, 110], [255, 160, 20], [235, 60, 10], [120, 10, 30], [40, 0, 20]].freeze
    ICE   = [[240, 255, 255], [130, 230, 255], [40, 140, 255], [30, 50, 190], [20, 10, 80]].freeze
    GOLD  = [[255, 255, 240], [255, 230, 120], [255, 190, 40], [200, 120, 0], [90, 40, 0]].freeze
    TOXIC = [[240, 255, 230], [150, 255, 120], [40, 220, 90], [0, 130, 70], [0, 50, 30]].freeze
    BLOOD = [[255, 230, 230], [255, 90, 90], [220, 20, 40], [130, 0, 20], [50, 0, 10]].freeze
    NEON  = [[255, 240, 255], [255, 110, 230], [190, 60, 255], [80, 40, 220], [30, 10, 90]].freeze
    SMOKE = [[235, 235, 235], [170, 170, 180], [110, 110, 125], [60, 60, 70], [30, 30, 35]].freeze
    STEEL = [[230, 240, 255], [150, 170, 200], [90, 105, 140], [50, 60, 85], [25, 28, 40]].freeze

    BASIC16 = [
      [0, 0, 0], [205, 0, 0], [0, 205, 0], [205, 205, 0], [0, 0, 238], [205, 0, 205], [0, 205, 205], [229, 229, 229],
      [127, 127, 127], [255, 0, 0], [0, 255, 0], [255, 255, 0], [92, 92, 255], [255, 0, 255], [0, 255, 255], [255, 255, 255],
    ].freeze

    module_function

    def clamp(x)
      x = x.to_i
      x < 0 ? 0 : (x > 255 ? 255 : x)
    end

    def mix(a, b, t)
      t = t < 0 ? 0.0 : (t > 1 ? 1.0 : t)
      [clamp(a[0] + (b[0] - a[0]) * t), clamp(a[1] + (b[1] - a[1]) * t), clamp(a[2] + (b[2] - a[2]) * t)]
    end

    def scale(c, k)
      [clamp(c[0] * k), clamp(c[1] * k), clamp(c[2] * k)]
    end

    def hsv(h, s = 1.0, v = 1.0)
      h = (h % 360) / 60.0
      i = h.floor
      f = h - i
      p = v * (1 - s)
      q = v * (1 - s * f)
      t = v * (1 - s * (1 - f))
      r, g, b = [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][i % 6]
      [clamp(r * 255), clamp(g * 255), clamp(b * 255)]
    end

    def rainbow(t, s = 0.85, v = 1.0)
      hsv(t * 360, s, v)
    end

    # t in 0..1 walks through the stops
    def ramp(stops, t)
      t = t < 0 ? 0.0 : (t > 1 ? 1.0 : t)
      pos = t * (stops.size - 1)
      i = pos.floor
      return stops[-1] if i >= stops.size - 1
      mix(stops[i], stops[i + 1], pos - i)
    end

    def sgr(fg, bg, bold, depth)
      codes = ["0"]
      codes << "1" if bold
      if depth == :none
        codes << "7" if bg && luminance(bg) > 90
      else
        codes << fg_code(fg, depth) if fg
        codes << bg_code(bg, depth) if bg
      end
      "\e[#{codes.join(';')}m"
    end

    def fg(c, depth, bold: false)
      sgr(c, nil, bold, depth)
    end

    def reset = "\e[0m"

    def fg_code(c, depth)
      case depth
      when :truecolor then "38;2;#{c[0]};#{c[1]};#{c[2]}"
      when :"256" then "38;5;#{to256(c)}"
      else
        i = to16(c)
        (i < 8 ? 30 + i : 82 + i).to_s
      end
    end

    def bg_code(c, depth)
      case depth
      when :truecolor then "48;2;#{c[0]};#{c[1]};#{c[2]}"
      when :"256" then "48;5;#{to256(c)}"
      else
        i = to16(c)
        (i < 8 ? 40 + i : 92 + i).to_s
      end
    end

    def luminance(c)
      0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    end

    def to256(c)
      r, g, b = c
      if (r - g).abs < 10 && (g - b).abs < 10
        return 16 if r < 8
        return 231 if r > 246
        return 232 + ((r - 8) / 10.0).round.clamp(0, 23)
      end
      q = ->(v) { v < 48 ? 0 : (v < 115 ? 1 : ((v - 35) / 40).clamp(0, 5)) }
      16 + 36 * q.(r) + 6 * q.(g) + q.(b)
    end

    def to16(c)
      best = 0
      bd = Float::INFINITY
      BASIC16.each_with_index do |bc, i|
        d = (bc[0] - c[0])**2 * 2 + (bc[1] - c[1])**2 * 4 + (bc[2] - c[2])**2 * 3
        if d < bd
          bd = d
          best = i
        end
      end
      best
    end
  end
end
