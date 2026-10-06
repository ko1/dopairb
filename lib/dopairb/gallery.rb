# frozen_string_literal: true

module Dopairb
  # Bonus art: famous public-domain paintings, painted procedurally at any
  # size (no bundled images). Each painter maps (u, v) in 0..1 to an RGB.
  module Gallery
    Piece = Struct.new(:id, :title, :artist, :year, :aspect, :painter, keyword_init: true)

    module Paint
      module_function

      def mix(a, b, t) = Color.mix(a, b, t)
      def smooth(e0, e1, x) = (t = Fx.clamp01((x - e0) / (e1 - e0))) * t * (3 - 2 * t)
      def dist(u, v, x, y, sx = 1.0) = Math.hypot((u - x) * sx, v - y)

      # Cheap deterministic value noise in 0..1.
      def noise(x, y)
        n = Math.sin(x * 12.9898 + y * 78.233) * 43_758.5453
        n - n.floor
      end

      def fbm(x, y)
        x0 = x.floor
        y0 = y.floor
        fx = x - x0
        fy = y - y0
        a = noise(x0, y0)
        b = noise(x0 + 1, y0)
        c = noise(x0, y0 + 1)
        d = noise(x0 + 1, y0 + 1)
        sx = fx * fx * (3 - 2 * fx)
        sy = fy * fy * (3 - 2 * fy)
        (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy
      end

      # Hokusai, Fine Wind, Clear Morning ("Red Fuji")
      def red_fuji(u, v)
        peak_u = 0.58
        peak_v = 0.17
        # concave slopes
        left = peak_v + (peak_u - u) * 1.05 + (peak_u - u)**2 * -0.5
        right = peak_v + (u - peak_u) * 0.95 + (u - peak_u)**2 * -0.3
        slope = u < peak_u ? left : right
        if v > 0.86
          return mix([20, 60, 50], [10, 30, 30], (v - 0.86) / 0.14) if noise((u * 60).floor, (v * 40).floor) < 0.8
          return [40, 90, 60]
        end
        if v >= slope
          depth = (v - peak_v) / 0.7
          if v > 0.74 + 0.03 * Math.sin(u * 30)
            tree = noise((u * 70).floor, (v * 50).floor) > 0.55
            return tree ? [35, 95, 60] : [25, 70, 50]
          end
          snow = v < peak_v + 0.13 + 0.05 * Math.sin(u * 55) * (v - peak_v) * 8
          return mix([250, 250, 245], [210, 215, 230], depth) if snow && Math.sin(u * 90) > -0.6
          base = mix([150, 40, 20], [205, 75, 35], depth * 1.3)
          streak = Math.sin(u * 140 + v * 10) > 0.75 ? 0.8 : 1.0
          return Color.scale(base, streak)
        end
        sky = mix([40, 80, 160], [175, 205, 230], smooth(0.0, 0.7, v))
        # mackerel clouds: rows of puffs low in the sky
        if v > 0.42
          row = ((v - 0.42) * 22)
          puff = Math.sin(u * 48 + row.floor * 1.7) * 0.5 + 0.5
          frac = row - row.floor
          return mix([255, 255, 250], sky, 0.25) if puff > 0.45 && frac.between?(0.15, 0.7)
        end
        sky
      end

      # Hokusai, The Great Wave off Kanagawa
      def great_wave(u, v)
        sky = mix([205, 195, 160], [235, 225, 195], v)
        # Mount Fuji, small in the trough
        fu = 0.64
        fv = 0.58
        if v > fv && v < 0.70 && (u - fu).abs < (v - fv) * 1.6
          return v < fv + 0.035 ? [245, 245, 240] : [70, 80, 110]
        end
        # the big wave: a crescent between two circles, curling to the right
        ox = (u - 0.36) * 1.2
        oy = v - 0.62
        outer = Math.hypot(ox, oy)
        inner = Math.hypot((u - 0.56) * 1.2, v - 0.66)
        if outer < 0.50 && inner > 0.30 && v < 0.80 && u < 0.78
          edge = 0.50 - outer
          ang = Math.atan2(oy, ox)
          claws = Math.sin(ang * 50) > 0.1
          return [250, 250, 245] if edge < 0.05 && (claws || edge < 0.02)
          lip = inner - 0.30
          return [250, 250, 245] if lip < 0.025 && v < 0.5
          stripe = Math.sin(outer * 110 + inner * 40) > 0.6
          base = mix([90, 135, 190], [15, 40, 105], Fx.clamp01(edge * 4))
          return stripe ? mix(base, [235, 240, 245], 0.7) : base
        end
        # foam spray dots falling from the crest
        if dist(u, v, 0.80, 0.22, 1.25) < 0.09 && noise((u * 80).floor, (v * 60).floor) > 0.72
          return [250, 250, 245]
        end
        sea_v = 0.70 + 0.04 * Math.sin(u * 14)
        if v > sea_v
          stripe = Math.sin(v * 160 + Math.sin(u * 25) * 4) > 0.7
          base = mix([40, 80, 140], [20, 45, 100], v)
          # boats
          [[0.30, 0.78], [0.62, 0.86]].each do |bx, by|
            return [215, 195, 140] if ((u - bx) / 0.13)**2 + ((v - by) / 0.025)**2 < 1
          end
          # small wave at right
          return [250, 250, 245] if dist(u, v, 0.86, 0.74, 1.4) < 0.10 && dist(u, v, 0.86, 0.74, 1.4) > 0.08
          return stripe ? [235, 240, 245] : base
        end
        sky
      end

      # van Gogh, The Starry Night
      def starry_night(u, v)
        # cypress, a dark flame on the left
        cyp = 0.17 + 0.09 * (v - 0.05) * 1.1 * Math.sin(v * 3) + 0.03 * Math.sin(v * 25)
        width = (v - 0.03) * 0.13
        if v > 0.03 && (u - cyp).abs < width
          return Math.sin(v * 70 + u * 30) > 0.3 ? [45, 70, 40] : [20, 30, 25]
        end
        hill = 0.70 + 0.06 * Math.sin(u * 5 + 1) + 0.03 * Math.sin(u * 13)
        if v > hill
          # village: houses with lit windows and a church spire
          return [30, 40, 70] if (u - 0.55).abs < 0.008 && v > hill - 0.18
          if v > hill + 0.07 && v < 0.93
            cell_x = (u * 40).floor
            cell_y = (v * 30).floor
            return [240, 210, 90] if noise(cell_x, cell_y) > 0.82
            return [55, 70, 105] if noise(cell_x + 3, cell_y) > 0.45
          end
          return Math.sin(u * 40 + v * 20) > 0.5 ? [35, 60, 100] : [25, 45, 80]
        end
        # moon
        dm = dist(u, v, 0.87, 0.13, 1.3)
        return [255, 235, 120] if dm < 0.05
        return [240, 200, 60] if dm < 0.075 && Math.sin(dm * 300) > 0
        # stars with halos
        [[0.10, 0.08], [0.30, 0.15], [0.48, 0.07], [0.66, 0.22], [0.78, 0.40], [0.40, 0.45], [0.95, 0.52], [0.22, 0.38]].each do |sx, sy|
          d = dist(u, v, sx, sy, 1.3)
          return [255, 250, 200] if d < 0.015
          return [235, 215, 90] if d < 0.035
          return [170, 190, 210] if d < 0.05 && Math.sin(d * 400) > 0.2
        end
        # the great swirl
        sx = u - 0.48
        sy = (v - 0.30) * 1.6
        r = Math.hypot(sx, sy)
        a = Math.atan2(sy, sx)
        swirl = Math.sin(r * 55 - a * 2 + Math.sin(u * 7) * 2)
        if r < 0.22 && swirl > 0.4
          return mix([230, 225, 170], [120, 160, 210], r / 0.22)
        end
        stroke = Math.sin(v * 60 + Math.sin(u * 9 + v * 4) * 5)
        base = mix([30, 60, 140], [70, 110, 180], smooth(0.0, 0.7, v))
        stroke > 0.6 ? mix(base, [150, 180, 220], 0.45) : base
      end

      # Leonardo da Vinci, Mona Lisa
      def mona_lisa(u, v)
        # dark frame
        land = mix([150, 160, 120], [90, 100, 60], v)
        land = mix(land, [70, 90, 80], 0.4) if Math.sin(u * 20 + v * 9) > 0.6
        fx = 0.50
        fy = 0.30
        face = ((u - fx) / 0.13)**2 + ((v - fy) / 0.15)**2
        hair = ((u - fx) / 0.20)**2 + ((v - fy - 0.04) / 0.22)**2
        if face < 1
          skin = mix([235, 190, 120], [180, 130, 70], Fx.clamp01((u - fx + 0.13) / 0.35) * 0.6 + face * 0.3)
          return [60, 40, 25] if (v - (fy - 0.02)).abs < 0.012 && ((u - fx).abs - 0.055).abs < 0.025 # eyes
          return [150, 80, 50] if (v - (fy + 0.085 + 0.25 * (u - fx)**2)).abs < 0.006 && (u - fx).abs < 0.045 # the smile
          return mix(skin, [150, 100, 55], 0.4) if (u - fx).abs < 0.008 && v > fy && v < fy + 0.05 # nose
          return skin
        end
        return [50, 35, 20] if hair < 1 && v < 0.55
        # neck and chest
        if v > 0.43 && v < 0.62 && (u - fx).abs < 0.05 + (v - 0.43) * 0.8
          return mix([225, 180, 115], [190, 140, 80], (v - 0.43) * 4)
        end
        # dress
        if v > 0.45 && (u - fx).abs < 0.12 + (v - 0.45) * 1.1
          # crossed hands
          return mix([235, 190, 125], [195, 145, 85], ((u - 0.5).abs) * 4) if ((u - 0.5) / 0.20)**2 + ((v - 0.88) / 0.06)**2 < 1
          return Math.sin(v * 90 + u * 10) > 0.8 ? [95, 70, 30] : [55, 40, 20]
        end
        land
      end

      # Munch, The Scream
      def the_scream(u, v)
        # the figure
        hx = 0.48
        hy = 0.62
        head = ((u - hx) / 0.08)**2 + ((v - hy) / 0.10)**2
        if head < 1
          return [40, 30, 30] if ((u - hx).abs - 0.03).abs < 0.015 && (v - hy + 0.02).abs < 0.02 # eyes
          return [40, 30, 30] if ((u - hx) / 0.015)**2 + ((v - hy - 0.05) / 0.03)**2 < 1 # mouth
          return [215, 205, 150]
        end
        # hands on cheeks
        return [200, 190, 140] if [[hx - 0.085, hy + 0.01], [hx + 0.085, hy + 0.01]].any? { |x, y| ((u - x) / 0.02)**2 + ((v - y) / 0.06)**2 < 1 }
        body_w = 0.07 + (v - hy) * 0.35 + 0.02 * Math.sin(v * 30)
        return Math.sin(v * 40 + u * 15) > 0.3 ? [45, 50, 70] : [25, 25, 40] if v > hy + 0.08 && (u - hx - (v - hy) * 0.1).abs < body_w
        # the bridge railing, from the left down to the bottom right
        rail = 0.48 + (u * 0.55)
        if v > rail - 0.015 && v < rail + 0.015
          return [130, 70, 40]
        end
        if v > rail
          return Math.sin((u + v) * 70) > 0.4 ? [190, 120, 70] : [160, 95, 55] # deck
        end
        # fjord and shore
        shore = 0.42 + 0.06 * Math.sin(u * 7)
        if v > shore
          return u < 0.5 + 0.1 * Math.sin(v * 10) ? mix([40, 60, 120], [70, 90, 130], Math.sin(v * 60 + u * 12) * 0.5 + 0.5) : mix([80, 100, 60], [140, 110, 60], Math.sin(u * 30 + v * 20) * 0.5 + 0.5)
        end
        # the blood-red sky
        wave = Math.sin(v * 38 + Math.sin(u * 6) * 2.5)
        if wave > 0.4 then [230, 90, 40]
        elsif wave > -0.2 then [245, 160, 60]
        elsif wave > -0.7 then [220, 190, 80]
        else [190, 60, 40]
        end
      end
    end

    PIECES = [
      Piece.new(id: :great_wave, title: "The Great Wave off Kanagawa", artist: "Katsushika Hokusai", year: "c. 1831", aspect: 1.5,
                painter: :great_wave),
      Piece.new(id: :red_fuji, title: "Fine Wind, Clear Morning", artist: "Katsushika Hokusai", year: "c. 1831", aspect: 1.45,
                painter: :red_fuji),
      Piece.new(id: :starry_night, title: "The Starry Night", artist: "Vincent van Gogh", year: "1889", aspect: 1.26,
                painter: :starry_night),
      Piece.new(id: :mona_lisa, title: "Mona Lisa", artist: "Leonardo da Vinci", year: "c. 1503", aspect: 0.67, painter: :mona_lisa),
      Piece.new(id: :the_scream, title: "The Scream", artist: "Edvard Munch", year: "1893", aspect: 0.8, painter: :the_scream),
    ].freeze

    module_function

    def find(id) = PIECES.find { |p| p.id == id.to_sym }
    def ids = PIECES.map(&:id)

    # Pixel grid (rows of RGB) of w x h pixels.
    def pixels(piece, w, h)
      @cache ||= {}
      @cache[[piece.id, w, h]] ||= Array.new(h) do |y|
        Array.new(w) { |x| Paint.public_send(piece.painter, (x + 0.5) / w, (y + 0.5) / h) }
      end
    end

    # Largest size that fits in cols x rows of cells (two pixels per cell, vertically).
    # => [pixel width, pixel height]
    def fit(piece, cols, rows)
      h = rows * 2
      w = (h * piece.aspect).round
      if w > cols
        w = cols
        h = (w / piece.aspect).round
      end
      [w, h - h % 2]
    end

    # Pick a piece for a reward: one not yet collected if possible.
    def pick(rng, owned = [])
      fresh = PIECES.reject { |p| owned.include?(p.id) }
      (fresh.empty? ? PIECES : fresh).sample(random: rng)
    end

    LUMA = " .:-=+*#%@"

    # Draw the piece into a canvas at (x, y). reveal: 0..1 rows shown top-down
    # (a curtain); depth :none falls back to luminance ASCII.
    def draw(canvas, piece, x, y, w, h, reveal: 1.0, depth: :truecolor, &tweak)
      px = pixels(piece, w, h)
      rows = h / 2
      shown = (rows * reveal).ceil
      half = Term.glyph("▀", nil)
      rows.times do |r|
        break if r >= shown
        w.times do |c|
          top = px[r * 2][c]
          bot = px[r * 2 + 1][c]
          top, bot = tweak.(top, bot, c, r) if tweak
          if depth == :none
            l = Color.luminance(Color.mix(top, bot, 0.5))
            canvas.put(x + c, y + r, LUMA[(l / 256.0 * LUMA.size).floor.clamp(0, LUMA.size - 1)])
          elsif half
            canvas.put(x + c, y + r, half, top, bg: bot)
          else
            canvas.put(x + c, y + r, " ", nil, bg: Color.mix(top, bot, 0.5))
          end
        end
      end
    end
  end
end
