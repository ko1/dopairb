# frozen_string_literal: true

module Dopairb
  module Gallery
    # Impressionists and Post-Impressionists. Painters live in Paint as
    # imp_* methods so they can use early returns.
    module Paint
      module_function

      # Distance from (u, v) to the segment a-b (sx scales the u axis).
      def imp_seg(u, v, ax, ay, bx, by, sx = 1.0)
        dx = (bx - ax) * sx
        dy = by - ay
        px = (u - ax) * sx
        py = v - ay
        t = ((px * dx + py * dy) / (dx * dx + dy * dy + 1e-12)).clamp(0.0, 1.0)
        Math.hypot(px - dx * t, py - dy * t)
      end

      # A standing figure: :head, :body or nil. top = top of the head, h = height, w = hem width.
      def imp_figure(u, v, cx, top, h, w)
        hr = h * 0.09
        return :head if ellipse(u, v, cx, top + hr, hr * 0.8, hr) < 1
        t = (v - top - hr * 1.8) / (h - hr * 1.8)
        return nil unless t.between?(0.0, 1.0)
        (u - cx).abs < w * (0.3 + 0.7 * t) * 0.5 ? :body : nil
      end

      # Thin dark line just outside a polygon.
      def imp_outline?(u, v, pts, e = 0.014)
        inside?(u + e, v, pts) || inside?(u - e, v, pts) || inside?(u, v + e, pts) || inside?(u, v - e, pts)
      end

      # Monet, Impression, Sunrise
      def imp_impression_sunrise(u, v)
        sx = 0.44
        sy = 0.34
        horizon = 0.50
        ds = dist(u, v, sx, sy, 1.31)
        return rgb(0xff6020) if ds < 0.030
        # boats: hull + standing rower
        [[0.36, 0.76, 0.075, 0.022, 0.0], [0.20, 0.64, 0.045, 0.015, 0.35], [0.53, 0.62, 0.04, 0.013, 0.45]].each do |bx, by, rx, ry, fade|
          dark = mix([25, 35, 50], [90, 110, 125], fade)
          return dark if ellipse(u, v, bx, by, rx, ry) < 1 && v > by - ry * 0.3
          return dark if (u - bx - rx * 0.2).abs < rx * 0.16 && v < by && v > by - ry * 3.2
        end
        if v > horizon
          # broken orange reflection streaks
          row = (v * 42).floor
          frac = v * 42 - row
          off = (noise(row, 3) - 0.5) * 0.05
          w = (0.02 + (v - horizon) * 0.12) * (noise(row, 7) > 0.2 ? 1 : 0)
          if (u - sx - off).abs < w && frac.between?(0.15, 0.8) && v < 0.97
            return mix([255, 120, 40], [230, 80, 30], noise(row, 9))
          end
          base = mix([95, 125, 135], [60, 90, 105], (v - horizon) * 2)
          stroke = brush(u, v, angle: 0.05, freq: 30.0, wobble: 0.6)
          base = mix(base, [140, 160, 160], 0.35) if stroke > 0.6
          base = mix(base, [50, 75, 90], 0.3) if stroke < -0.7
          return jitter(base, u, v, 10)
        end
        # cranes, masts and chimneys, faint in the haze
        [[0.06, 0.12, 0.004], [0.10, 0.22, 0.004], [0.62, 0.18, 0.005], [0.70, 0.10, 0.004], [0.83, 0.22, 0.004], [0.90, 0.16, 0.004]].each do |mx, top, half|
          return mix([110, 125, 135], [140, 150, 155], 0.3) if (u - mx).abs < half + 0.003 && v > top
        end
        return mix([110, 125, 135], [135, 145, 150], 0.4) if v > 0.40 && (u < 0.30 || u > 0.66) && vnoise(u, v, 10) > 0.4
        sky = mix([125, 145, 155], [160, 165, 160], v * 1.5)
        glow = Math.exp(-ds * 7)
        sky = mix(sky, [235, 150, 100], glow * 0.8)
        sky = mix(sky, [210, 150, 125], 0.25) if v < 0.25 && brush(u, v, angle: -0.15, freq: 12.0) > 0.6 && u > 0.3
        jitter(sky, u, v, 10)
      end

      # Monet, Water Lilies
      def imp_water_lilies(u, v)
        clusters = [[0.22, 0.10, 0.20, 0.035], [0.75, 0.16, 0.22, 0.04], [0.48, 0.36, 0.28, 0.055],
                    [0.14, 0.58, 0.20, 0.07], [0.78, 0.62, 0.24, 0.08], [0.42, 0.88, 0.32, 0.09]]
        clusters.each_with_index do |(cx, cy, rx, ry), i|
          e = ellipse(u, v, cx, cy, rx, ry) + (vnoise(u, v, 14.0) - 0.5) * 0.9
          next unless e < 1
          # flowers
          return [250, 245, 245] if dist(u, v, cx + rx * 0.25, cy - ry * 0.1, 1.1) < 0.022 + ry * 0.15 && i.even?
          return [240, 140, 170] if dist(u, v, cx - rx * 0.35, cy, 1.1) < 0.02 + ry * 0.2
          return [250, 220, 230] if dist(u, v, cx + rx * 0.05, cy + ry * 0.2, 1.1) < 0.012 + ry * 0.15 && i.odd?
          pad = brush(u, v, angle: 0.0, freq: 70.0, wobble: 0.8) > 0 ? [90, 150, 70] : [130, 175, 80]
          pad = mix(pad, [200, 200, 90], 0.4) if vnoise(u, v, 25.0) > 0.7
          return pad
        end
        # pond: blue-violet sky reflections with green vertical willow reflections
        base = ramp(v, [90, 110, 170], [120, 140, 200], [100, 120, 180], [70, 90, 150])
        refl = Math.sin(u * 22 + vnoise(u, v, 4.0) * 4)
        base = mix(base, [60, 110, 90], 0.55) if refl > 0.5
        base = mix(base, [190, 190, 220], 0.4) if vnoise(u * 0.3, v * 3, 6.0) > 0.68
        base = mix(base, [150, 120, 190], 0.3) if brush(u, v, angle: 0.0, freq: 45.0) > 0.7
        jitter(base, u, v, 12)
      end

      # Monet, Woman with a Parasol
      def imp_woman_with_a_parasol(u, v)
        ground = 0.83 + 0.04 * Math.sin(u * 4 + 0.5)
        # grass in the foreground
        if v > ground
          g = brush(u, v, angle: 1.1, freq: 40.0, wobble: 0.8) > 0.2 ? [120, 160, 60] : [70, 120, 50]
          g = mix(g, [210, 200, 90], 0.5) if vnoise(u, v, 18.0) > 0.65
          return g
        end
        # the boy at right, half hidden by the slope
        return [235, 230, 200] if ellipse(u, v, 0.82, 0.715, 0.03, 0.018) < 1
        return [200, 160, 130] if ellipse(u, v, 0.82, 0.745, 0.022, 0.025) < 1
        return [220, 210, 180] if (u - 0.82).abs < 0.035 && v > 0.77
        # parasol, tilted (its right side lower)
        pv = v - (u - 0.42) * 0.22
        if pv < 0.245 && ellipse(u, pv, 0.42, 0.245, 0.27, 0.17) < 1
          shade = smooth(0.15, 0.68, u)
          return mix([110, 170, 90], [40, 90, 60], shade) if brush(u, v, angle: 0.8, freq: 30.0) > -0.3
          return [70, 120, 70]
        end
        return mix([200, 180, 90], [100, 110, 60], u) if pv >= 0.245 && ellipse(u, pv, 0.42, 0.245, 0.27, 0.045) < 1
        # handle
        return [70, 60, 50] if imp_seg(u, v, 0.43, 0.25, 0.47, 0.44) < 0.008
        # head with hat and blowing veil
        return [190, 160, 110] if ellipse(u, v, 0.48, 0.355, 0.035, 0.035) < 1
        return [235, 240, 245] if ellipse(u, v, 0.40, 0.38, 0.08, 0.018 + (0.48 - u).abs * 0.05) < 1 && u < 0.47
        # white dress, blown to the left
        dress = [[0.45, 0.385], [0.52, 0.39], [0.57, 0.52], [0.61, 0.90], [0.36, 0.90], [0.33, 0.70], [0.40, 0.52]]
        if inside?(u, v, dress)
          side = smooth(0.38, 0.58, u)
          c = mix([170, 190, 225], [250, 245, 220], side)
          c = mix(c, [235, 225, 160], 0.4) if brush(u, v, angle: 0.4, freq: 35.0) > 0.6 && u > 0.5
          return c
        end
        # sky with wind-blown clouds
        sky = mix([90, 145, 210], [175, 205, 235], smooth(0.0, 0.85, v))
        cloud = vnoise(u * 1.4 + v * 0.6, v, 4.0) + brush(u, v, angle: -0.6, freq: 18.0) * 0.12
        sky = mix(sky, [245, 245, 240], smooth(0.56, 0.74, cloud))
        jitter(sky, u, v, 8)
      end

      # Monet, The Water Lily Pond (Japanese Footbridge)
      def imp_japanese_footbridge(u, v)
        deck = 0.44 - 0.12 * Math.sin(Math::PI * u)
        # the arched green bridge with its railing
        return mix([160, 190, 110], [100, 150, 80], u) if v > deck && v < deck + 0.04
        return [80, 130, 70] if v > deck + 0.04 && v < deck + 0.065
        top = deck - 0.12
        return [190, 210, 140] if (v - top).abs < 0.013
        return [150, 185, 110] if (v - (deck - 0.06)).abs < 0.01
        return [130, 175, 100] if v > top && v < deck && ((u * 12.5) % 1.0) < 0.18
        if v > 0.50 + 0.04 * Math.sin(u * 6)
          # pond with rows of lily pads
          row = ((v - 0.5) * 22).floor
          rh = (v - 0.5) * 22 - row
          cw = 0.10 + row * 0.01
          cell = ((u + noise(row, 1) * 0.3) / cw).floor
          cu = (u + noise(row, 1) * 0.3) / cw - cell
          if noise(cell, row) > 0.3 && ((cu - 0.5) / 0.45)**2 + ((rh - 0.5) / 0.4)**2 < 1
            return [235, 150, 170] if noise(cell, row + 50) > 0.85 && (cu - 0.5).abs < 0.15
            return [250, 245, 240] if noise(cell, row + 70) > 0.85 && (cu - 0.5).abs < 0.15
            return mix([140, 180, 70], [90, 150, 60], noise(cell, row + 9))
          end
          water = mix([40, 80, 60], [70, 110, 90], vnoise(u, v, 6.0))
          water = mix(water, [150, 170, 120], 0.4) if Math.sin(u * 40 + vnoise(u, v, 5.0) * 3) > 0.75
          return water
        end
        # dense willow and bamboo foliage
        f = vnoise(u, v, 16.0)
        stroke = brush(u, v, angle: 1.5, freq: 50.0, wobble: 0.6)
        c = ramp(f, [30, 60, 35], [60, 110, 50], [110, 160, 70], [180, 200, 90])
        c = mix(c, [40, 80, 70], 0.4) if stroke > 0.6
        jitter(c, u, v, 14)
      end

      # Monet, Poppy Field
      def imp_poppy_field(u, v)
        horizon = 0.30 + 0.20 * u
        # foreground pair: woman with blue parasol and child
        return [60, 80, 130] if ellipse(u, v, 0.70, 0.50, 0.065, 0.045) < 1 && v < 0.52
        case imp_figure(u, v, 0.71, 0.53, 0.30, 0.13)
        when :head then return [200, 160, 130]
        when :body then return [45, 45, 60]
        end
        case imp_figure(u, v, 0.79, 0.66, 0.18, 0.08)
        when :head then return [220, 200, 140]
        when :body then return [230, 225, 205]
        end
        # background pair high on the hill
        return [70, 100, 160] if ellipse(u, v, 0.30, 0.37, 0.035, 0.025) < 1 && v < 0.38
        case imp_figure(u, v, 0.30, 0.38, 0.14, 0.06)
        when :head then return [200, 170, 140]
        when :body then return [50, 50, 60]
        end
        case imp_figure(u, v, 0.36, 0.44, 0.08, 0.04)
        when :head, :body then return [210, 200, 180]
        end
        if v > horizon
          ground = mix([140, 170, 80], [90, 140, 60], (v - horizon) * 1.5)
          ground = mix(ground, [190, 190, 110], 0.35) if vnoise(u, v, 8.0) > 0.65
          poppy_zone = u < 0.70 - (v - 0.4) * 0.6 + (vnoise(u, v, 5.0) - 0.5) * 0.2
          cell = noise((u * 64).floor, (v * 48).floor)
          return mix([230, 60, 30], [190, 30, 25], noise((u * 64).floor + 7, (v * 48).floor)) if poppy_zone && cell > 0.6
          return [220, 60, 35] if cell > 0.95
          return jitter(ground, u, v, 12)
        end
        # row of trees and a red-roofed house on the horizon
        tree_top = horizon - 0.07 - vnoise(u, 0.0, 12.0) * 0.08
        if u > 0.35 && u < 0.97 && v > tree_top
          return [210, 120, 80] if (u - 0.62).abs < 0.025 && v > horizon - 0.04
          return mix([40, 70, 50], [80, 110, 70], vnoise(u, v, 20.0))
        end
        sky = mix([110, 150, 210], [190, 210, 230], v * 2)
        sky = mix(sky, [245, 245, 240], smooth(0.5, 0.7, vnoise(u * 1.3, v, 5.0)))
        jitter(sky, u, v, 8)
      end

      # Renoir, Bal du moulin de la Galette
      def imp_bal_du_moulin(u, v)
        light = vnoise(u, v, 13.0) > 0.66
        dapple = ->(c) { light ? mix(c, [250, 235, 200], 0.45) : c }
        # foreground: woman in pink-and-blue stripes
        return [60, 40, 30] if ellipse(u, v, 0.30, 0.45, 0.035, 0.045) < 1 && v < 0.44
        return [235, 195, 170] if ellipse(u, v, 0.30, 0.47, 0.03, 0.04) < 1
        stripe_dress = [[0.27, 0.51], [0.33, 0.51], [0.37, 0.70], [0.42, 1.0], [0.18, 1.0], [0.24, 0.70]]
        if inside?(u, v, stripe_dress)
          return dapple.(Math.sin(u * 160 + v * 20) > 0 ? [235, 190, 200] : [80, 100, 170])
        end
        # seated group at right: a man in dark coat, a striped woman, the table
        return [225, 210, 120] if ellipse(u, v, 0.78, 0.53, 0.06, 0.02) < 1
        return [225, 190, 160] if ellipse(u, v, 0.78, 0.58, 0.03, 0.04) < 1
        return dapple.([30, 30, 45]) if inside?(u, v, [[0.72, 0.62], [0.84, 0.62], [0.92, 1.0], [0.66, 1.0]])
        return [235, 195, 175] if ellipse(u, v, 0.58, 0.60, 0.028, 0.036) < 1
        if inside?(u, v, [[0.55, 0.64], [0.62, 0.64], [0.66, 1.0], [0.50, 1.0]])
          return dapple.(Math.sin(u * 160) > 0 ? [240, 220, 225] : [90, 110, 180])
        end
        return [235, 235, 220] if ellipse(u, v, 0.95, 0.80, 0.08, 0.03) < 1
        # lamps on posts under the trees
        [[0.16, 0.10], [0.40, 0.06], [0.62, 0.12], [0.86, 0.07]].each do |lx, ly|
          d = dist(u, v, lx, ly, 1.33)
          return [250, 245, 220] if d < 0.025
          return [235, 220, 170] if d < 0.035
        end
        # the dancing crowd
        if v > 0.20 && v < 0.80
          # two staggered rows of dancers: nearer (bigger) first
          [[11.0, 0.34, 0.032, 0.37], [19.0, 0.23, 0.02, 0.0]].each_with_index do |(cols, base, hr, shift), row|
            col = (u * cols + shift).floor
            next if noise(col, row + 20) < 0.25
            cx = (col + 0.5 - shift) / cols + (noise(col, row + 30) - 0.5) * 0.3 / cols
            hy = base + noise(col, row + 1) * 0.06
            return [230, 190, 160] if ellipse(u, v, cx, hy, hr * 0.65, hr) < 1
            return [225, 205, 120] if noise(col, row + 4) > 0.6 && ellipse(u, v, cx, hy - hr * 0.9, hr * 1.2, hr * 0.45) < 1
            return [35, 30, 30] if ellipse(u, v, cx, hy - hr * 0.7, hr * 0.7, hr * 0.5) < 1
            next unless v > hy + hr && (u - cx).abs < hr * 1.3 + (v - hy) * 0.12
            n = noise(col, row + 2)
            cloth = if n < 0.45 then [30, 30, 45]
                    elsif n < 0.65 then [60, 80, 150]
                    elsif n < 0.8 then [230, 200, 210]
                    else [40, 60, 90]
                    end
            return dapple.(cloth)
          end
        end
        if v < 0.30
          leaves = mix([40, 70, 60], [90, 120, 90], vnoise(u, v, 18.0))
          return dapple.(leaves)
        end
        jitter(dapple.(mix([150, 145, 150], [175, 155, 140], v)), u, v, 14)
      end

      DANCERS = [
        [0.06, 0.28, 1.0, [60, 150, 90]], [0.15, 0.30, 1.0, [70, 110, 200]], [0.24, 0.28, 0.95, [230, 190, 60]],
        [0.70, 0.28, 0.9, [210, 60, 50]], [0.80, 0.30, 0.9, [80, 120, 200]], [0.90, 0.27, 0.9, [230, 150, 170]],
        [0.84, 0.56, 1.5, [70, 160, 110]], [0.14, 0.58, 1.45, [230, 110, 50]]
      ].freeze

      # Degas, The Dance Class
      def imp_the_dance_class(u, v)
        DANCERS.reverse_each do |cx, hy, s, sash|
          return [70, 45, 30] if ellipse(u, v, cx, hy, 0.022 * s, 0.022 * s) < 1 && v < hy - 0.005
          return [235, 200, 175] if ellipse(u, v, cx, hy + 0.01 * s, 0.02 * s, 0.026 * s) < 1
          return sash if (v - hy - 0.085 * s).abs < 0.012 * s && (u - cx).abs < 0.03 * s
          return [245, 245, 240] if (u - cx).abs < 0.02 * s && v > hy + 0.03 * s && v < hy + 0.09 * s
          return mix([250, 250, 245], [210, 215, 220], ((u - cx) / (0.07 * s)).abs) if ellipse(u, v, cx, hy + 0.115 * s, 0.07 * s, 0.035 * s) < 1
          return [235, 190, 180] if ((u - cx).abs - 0.012 * s).abs < 0.006 * s && v > hy + 0.12 * s && v < hy + 0.23 * s
        end
        # the dance master leaning on his cane
        return [235, 235, 230] if ellipse(u, v, 0.55, 0.30, 0.025, 0.03) < 1 && v < 0.29
        return [225, 185, 155] if ellipse(u, v, 0.55, 0.315, 0.023, 0.03) < 1
        return [70, 55, 45] if imp_seg(u, v, 0.585, 0.45, 0.62, 0.74) < 0.006
        case imp_figure(u, v, 0.555, 0.33, 0.40, 0.11)
        when :body then return mix([110, 95, 80], [80, 70, 60], (u - 0.5) * 8)
        end
        floor_line = 0.47
        if v > floor_line
          a = Math.atan2(v - 0.20, u - 0.62)
          base = mix([205, 165, 120], [175, 125, 85], (v - floor_line) * 1.6)
          return Color.scale(base, 0.85) if Math.sin(a * 46) > 0.8
          return jitter(base, u, v, 8, 60.0)
        end
        # pilaster and doorway with mirror
        return [205, 205, 185] if u > 0.31 && u < 0.37
        return [215, 215, 195] if u > 0.29 && u < 0.39 && v < 0.05
        return mix([130, 145, 140], [160, 170, 160], vnoise(u, v, 10.0)) if u > 0.77 && u < 0.97 && v > 0.05
        jitter(mix([180, 190, 170], [160, 170, 150], v * 2), u, v, 10)
      end

      # Seurat, A Sunday on La Grande Jatte (scene before pointillist dots)
      def imp_grande_jatte_scene(u, v)
        dark = [35, 40, 50]
        # couple in profile at right: woman with bustle and parasol, man in top hat
        return [150, 60, 50] if ellipse(u, v, 0.79, 0.28, 0.06, 0.035) < 1 && v < 0.29
        return [60, 40, 40] if imp_seg(u, v, 0.79, 0.28, 0.80, 0.40) < 0.006
        return [230, 190, 160] if ellipse(u, v, 0.80, 0.36, 0.012, 0.02) < 1
        return dark if inside?(u, v, [[0.79, 0.39], [0.82, 0.39], [0.83, 0.55], [0.88, 0.60], [0.86, 0.96], [0.74, 0.96], [0.77, 0.55]])
        return [20, 20, 25] if (u - 0.905).abs < 0.014 && v > 0.22 && v < 0.29
        return [20, 20, 25] if (u - 0.905).abs < 0.025 && (v - 0.29).abs < 0.006
        return [230, 190, 160] if ellipse(u, v, 0.905, 0.32, 0.013, 0.025) < 1
        return [30, 30, 40] if inside?(u, v, [[0.89, 0.35], [0.93, 0.35], [0.95, 0.96], [0.87, 0.96]])
        # woman with child in white, center
        return [245, 245, 240] if (case imp_figure(u, v, 0.52, 0.48, 0.20, 0.07) when :head, :body then true end)
        case imp_figure(u, v, 0.47, 0.38, 0.34, 0.11)
        when :head then return [230, 190, 160]
        when :body then return [120, 50, 70]
        end
        # seated woman with orange parasol, reclining man at lower left
        return [230, 120, 50] if ellipse(u, v, 0.22, 0.52, 0.06, 0.035) < 1 && v < 0.53
        return dark if ellipse(u, v, 0.23, 0.63, 0.05, 0.08) < 1
        return [45, 35, 30] if ellipse(u, v, 0.11, 0.80, 0.10, 0.045) < 1
        return [235, 200, 170] if ellipse(u, v, 0.04, 0.76, 0.02, 0.03) < 1
        # small distant strollers
        [[0.35, 0.30, 0.12], [0.62, 0.26, 0.11], [0.68, 0.33, 0.13], [0.42, 0.25, 0.08], [0.58, 0.40, 0.12]].each do |fx, fy, fh|
          return dark if imp_figure(u, v, fx, fy, fh, fh * 0.35)
        end
        # trees: canopy at top, trunks
        return [40, 70, 40] if v < 0.10 + 0.05 * vnoise(u, 0.0, 9.0)
        return [70, 60, 45] if ((u - 0.30).abs < 0.012 || (u - 0.70).abs < 0.014) && v < 0.42
        # the river at top left
        if v < 0.42 - u * 0.75
          return [250, 250, 245] if ellipse(u, v, 0.12, 0.20, 0.03, 0.03) < 1 && v < 0.21
          return [140, 175, 210]
        end
        # grass: shade in front, sun behind
        shade = v > 0.70 - 0.08 * u + 0.04 * Math.sin(u * 7)
        shade ? [40, 95, 55] : [160, 200, 80]
      end

      def imp_grande_jatte(u, v)
        c = imp_grande_jatte_scene(u, v)
        cx = (u * 100).floor
        cy = (v * 68).floor
        n = noise(cx, cy)
        if n < 0.2 then mix(c, [240, 150, 60], 0.3)
        elsif n > 0.82 then mix(c, [70, 110, 210], 0.3)
        elsif n > 0.65 then mix(c, [255, 250, 220], 0.2)
        else jitter(c, u, v, 12, 90.0)
        end
      end

      # Manet, A Bar at the Folies-Bergere
      def imp_bar_folies(u, v)
        skin = [240, 215, 195]
        # bottles on the marble counter
        [[0.05, [40, 70, 40]], [0.09, [120, 40, 30]], [0.13, [40, 70, 40]], [0.18, [200, 120, 40]], [0.84, [40, 70, 40]], [0.89, [120, 40, 30]]].each do |bx, bc|
          next unless v > 0.52 && v < 0.72
          return [230, 190, 80] if (u - bx).abs < 0.009 && v < 0.56
          return bc if (u - bx).abs < (v < 0.60 ? 0.008 : 0.016)
        end
        return [240, 140, 40] if ellipse(u, v, 0.67, 0.69, 0.06, 0.03) < 1 && v < 0.70
        # barmaid: hair, face, dark bodice with lace, hands on the counter
        return [190, 140, 80] if ellipse(u, v, 0.50, 0.26, 0.05, 0.05) < 1 && v < 0.27
        return skin if ellipse(u, v, 0.50, 0.30, 0.04, 0.06) < 1
        return skin if (u - 0.5).abs < 0.022 && v > 0.34 && v < 0.40
        body = [[0.42, 0.40], [0.58, 0.40], [0.62, 0.68], [0.38, 0.68]]
        if inside?(u, v, body)
          return [240, 150, 160] if ellipse(u, v, 0.53, 0.46, 0.02, 0.02) < 1
          return [235, 230, 225] if v < 0.47 && (u - 0.5).abs < (0.47 - v) * 0.9
          return [35, 35, 55]
        end
        return skin if ellipse(u, v, 0.39, 0.68, 0.025, 0.02) < 1 || ellipse(u, v, 0.61, 0.68, 0.025, 0.02) < 1
        # marble counter
        if v > 0.68
          return [120, 110, 100] if v > 0.73 && v < 0.745
          return mix([235, 225, 210], [200, 190, 180], v > 0.745 ? 0.6 : 0.0)
        end
        # in the mirror: her back and the man in a top hat
        return [190, 150, 100] if ellipse(u, v, 0.80, 0.33, 0.035, 0.045) < 1
        return [55, 50, 65] if inside?(u, v, [[0.76, 0.37], [0.84, 0.37], [0.87, 0.68], [0.73, 0.68]])
        return [25, 25, 30] if (u - 0.93).abs < 0.03 && v > 0.17 && v < 0.27
        return [210, 180, 150] if ellipse(u, v, 0.93, 0.31, 0.03, 0.045) < 1
        return [40, 40, 45] if u > 0.89 && v > 0.35 && v < 0.68
        # chandeliers and lamps
        [[0.27, 0.13, 0.06], [0.63, 0.10, 0.05], [0.08, 0.30, 0.025], [0.40, 0.24, 0.025]].each do |lx, ly, r|
          d = dist(u, v, lx, ly, 1.35)
          return [255, 250, 230] if d < r * 0.5
          return mix([255, 240, 190], [200, 180, 140], (d - r * 0.5) / (r * 0.5)) if d < r
        end
        return [80, 160, 70] if dist(u, v, 0.03, 0.06, 1.35) < 0.02
        return [190, 160, 90] if (v - 0.22).abs < 0.01
        crowd = ramp(vnoise(u, v, 14.0), [120, 105, 90], [175, 160, 140], [215, 205, 185], [235, 225, 200])
        crowd = mix(crowd, [60, 55, 60], 0.5) if v > 0.30 && noise((u * 30).floor, (v * 20).floor) > 0.7
        jitter(crowd, u, v, 12)
      end

      # Manet, Luncheon on the Grass
      def imp_luncheon(u, v)
        pale = [235, 220, 195]
        suit = [30, 30, 35]
        # still life at lower left: fruit, basket, blue dress
        return [210, 60, 40] if dist(u, v, 0.15, 0.80, 1.27) < 0.018
        return [235, 160, 50] if dist(u, v, 0.20, 0.81, 1.27) < 0.018
        return [150, 110, 50] if ellipse(u, v, 0.17, 0.86, 0.07, 0.035) < 1
        return [110, 140, 190] if ellipse(u, v, 0.07, 0.86, 0.08, 0.06) < 1
        return [230, 200, 110] if ellipse(u, v, 0.08, 0.76, 0.05, 0.02) < 1
        # reclining man at right with black cap
        return [20, 20, 25] if ellipse(u, v, 0.64, 0.42, 0.035, 0.022) < 1 && v < 0.43
        return [220, 180, 150] if ellipse(u, v, 0.64, 0.46, 0.028, 0.04) < 1
        return suit if ellipse(u, v, 0.68, 0.60, 0.09, 0.10) < 1
        return suit if imp_seg(u, v, 0.70, 0.66, 0.92, 0.78, 1.27) < 0.04
        return [230, 190, 160] if ellipse(u, v, 0.57, 0.58, 0.02, 0.02) < 1
        # middle man
        return [120, 90, 60] if ellipse(u, v, 0.47, 0.40, 0.03, 0.025) < 1 && v < 0.40
        return [220, 180, 150] if ellipse(u, v, 0.47, 0.43, 0.027, 0.038) < 1
        return suit if ellipse(u, v, 0.48, 0.58, 0.07, 0.11) < 1
        return suit if imp_seg(u, v, 0.48, 0.66, 0.44, 0.86, 1.27) < 0.035
        # pale seated figure at left
        return [40, 30, 25] if ellipse(u, v, 0.33, 0.42, 0.035, 0.03) < 1 && v < 0.43
        return pale if ellipse(u, v, 0.33, 0.45, 0.03, 0.04) < 1
        return pale if ellipse(u, v, 0.31, 0.60, 0.06, 0.11) < 1
        return pale if ellipse(u, v, 0.39, 0.72, 0.09, 0.045) < 1
        # bathing woman in the clearing
        return [235, 235, 225] if ellipse(u, v, 0.50, 0.30, 0.03, 0.05) < 1
        if ellipse(u, v, 0.50, 0.26, 0.16, 0.26) + (vnoise(u, v, 9.0) - 0.5) * 0.9 < 1 && v > 0.04
          return mix([100, 130, 100], [140, 160, 120], vnoise(u, v, 8.0)) if v > 0.30
          return mix([120, 150, 90], [170, 185, 130], vnoise(u, v, 9.0))
        end
        if v > 0.70 + 0.04 * Math.sin(u * 9)
          return jitter(mix([60, 80, 40], [40, 55, 30], v), u, v, 14)
        end
        woods = ramp(vnoise(u, v, 10.0), [15, 30, 20], [35, 60, 35], [60, 90, 50], [90, 110, 60])
        jitter(woods, u, v, 10)
      end

      SUNFLOWERS = [
        [0.36, 0.56, 0.07, 1], [0.58, 0.55, 0.075, 0], [0.18, 0.58, 0.07, 1], [0.78, 0.62, 0.07, 0],
        [0.44, 0.36, 0.10, 0], [0.24, 0.40, 0.085, 0], [0.64, 0.40, 0.09, 1], [0.84, 0.42, 0.08, 0],
        [0.30, 0.20, 0.09, 0], [0.52, 0.14, 0.085, 1], [0.72, 0.22, 0.09, 0], [0.12, 0.24, 0.07, 1],
        [0.88, 0.25, 0.065, 1], [0.64, 0.06, 0.06, 0]
      ].freeze

      # van Gogh, Sunflowers
      def imp_sunflowers(u, v)
        # vase with the blue line
        if v > 0.62 && v < 0.93
          half = 0.11 + 0.035 * Math.sin(Math::PI * (v - 0.62) / 0.31)
          if (u - 0.48).abs < half
            return [60, 90, 170] if (v - 0.72).abs < 0.009
            return v < 0.72 ? mix([245, 210, 90], [215, 170, 60], (u - 0.48) / half) : mix([230, 175, 60], [190, 130, 40], (u - 0.48) / half)
          end
        end
        SUNFLOWERS.each do |fx, fy, r, kind|
          d = dist(u, v, fx, fy, 0.79)
          next if d > r
          a = Math.atan2(v - fy, (u - fx) * 0.79)
          return (kind == 1 ? [190, 110, 30] : [150, 80, 25]) if d < r * 0.45 && noise((u * 90).floor, (v * 70).floor) > 0.25
          return [110, 60, 20] if d < r * 0.45
          return (Math.sin(a * 13) > 0 ? [245, 185, 30] : [230, 150, 30]) if d < r * (0.78 + 0.22 * Math.sin(a * 13))
        end
        # stems
        return [110, 130, 40] if [[0.36, 0.56], [0.58, 0.55], [0.44, 0.36], [0.64, 0.40]].any? { |sx, sy| imp_seg(u, v, sx, sy, 0.48, 0.63) < 0.007 } && v < 0.63
        # table and wall
        return [195, 130, 40] if (v - 0.78).abs < 0.007
        if v > 0.78
          return jitter(mix([225, 170, 60], [210, 150, 50], brush(u, v, angle: 0.1, freq: 40.0) * 0.5 + 0.5), u, v, 8)
        end
        wall = brush(u, v, angle: 0.9, freq: 30.0, wobble: 0.5) > 0.3 ? [240, 215, 110] : [230, 200, 90]
        jitter(wall, u, v, 8)
      end

      # van Gogh, Cafe Terrace at Night
      def imp_cafe_terrace(u, v)
        # yellow awning in perspective
        awn_top = 0.02 + u * 0.45
        awn_bot = 0.36 - u * 0.05
        if u < 0.48 && v > awn_top && v < awn_bot
          return Math.sin(u * 50) > 0.7 ? [235, 160, 40] : [250, 210, 60]
        end
        # building above the awning
        return mix([50, 70, 90], [80, 90, 100], vnoise(u, v, 10.0)) if u < 0.48 && v <= awn_top
        terrace_edge = 0.86 - u * 0.5
        if u < 0.50 && v >= awn_bot && v < terrace_edge
          # tables and patrons on the lit terrace
          [[0.10, 0.62, 0.06], [0.24, 0.58, 0.05], [0.36, 0.53, 0.04], [0.20, 0.72, 0.07], [0.42, 0.48, 0.03]].each do |tx, ty, r|
            return [235, 235, 200] if ellipse(u, v, tx, ty, r, r * 0.35) < 1
            return [60, 50, 40] if (u - tx).abs < 0.006 && v > ty && v < ty + r * 1.2
          end
          return [50, 50, 60] if imp_figure(u, v, 0.30, 0.44, 0.12, 0.05)
          return mix([240, 180, 60], [220, 140, 40], vnoise(u, v, 12.0)) if v < 0.48
          return mix([240, 190, 90], [225, 160, 60], vnoise(u, v, 14.0))
        end
        # dark buildings at right
        if u > 0.80 - v * 0.05 && v < 0.82
          return [240, 190, 80] if ((u * 18) % 1.0) < 0.35 && ((v * 14) % 1.0) < 0.3 && v > 0.25 && noise((u * 18).floor, (v * 14).floor) > 0.5
          return mix([30, 55, 70], [55, 75, 70], vnoise(u, v, 9.0))
        end
        # starry corridor of sky
        if v < 0.38 + 0.02 * Math.sin(u * 30)
          [[0.55, 0.08], [0.67, 0.05], [0.76, 0.14], [0.60, 0.21], [0.71, 0.27], [0.53, 0.30], [0.66, 0.35]].each do |sx, sy|
            d = dist(u, v, sx, sy, 0.81)
            return [255, 250, 220] if d < 0.014
            return [220, 220, 170] if d < 0.024
          end
          return mix([20, 40, 120], [40, 70, 160], v * 2.2 + (brush(u, v, angle: 0.5, freq: 25.0) * 0.1))
        end
        # distant street and walkers
        return [40, 40, 50] if imp_figure(u, v, 0.62, 0.42, 0.10, 0.04) || imp_figure(u, v, 0.70, 0.44, 0.09, 0.035)
        return [45, 60, 90] if v < 0.48
        # cobblestones
        sv = 1.0 / (v - 0.38)
        su = (u - 0.62) * sv
        cell_x = (su * 4).floor
        cell_y = (sv * 5).floor
        fx = su * 4 - cell_x
        fy = sv * 5 - cell_y
        return [40, 40, 70] if fx < 0.15 || fy < 0.15
        stone = noise(cell_x, cell_y)
        return [230, 160, 120] if stone > 0.75 && u < 0.7
        mix([90, 100, 160], [130, 120, 170], stone)
      end

      CROWS = [[0.30, 0.18, 0.035], [0.42, 0.10, 0.03], [0.55, 0.22, 0.04], [0.64, 0.12, 0.03], [0.72, 0.28, 0.035],
               [0.80, 0.16, 0.03], [0.48, 0.35, 0.04], [0.60, 0.42, 0.035], [0.86, 0.33, 0.03], [0.22, 0.30, 0.03],
               [0.38, 0.44, 0.03]].freeze

      # van Gogh, Wheatfield with Crows
      def imp_wheatfield_with_crows(u, v)
        aspect = 2.04
        CROWS.each do |cx, cy, s|
          du = (u - cx) * aspect
          next if du.abs > s
          return [15, 15, 20] if (v - (cy - du.abs * 0.6)).abs < 0.022
        end
        horizon = 0.42 + 0.03 * Math.sin(u * 5)
        if v < horizon
          sky = mix([15, 30, 90], [40, 80, 160], vnoise(u, v, 6.0) + v)
          sky = mix(sky, [80, 130, 200], 0.6) if brush(u, v, angle: 0.3 + vnoise(u, v, 3.0), freq: 25.0, wobble: 0.8) > 0.5
          [[0.25, 0.20], [0.78, 0.14]].each do |cx, cy|
            sky = mix(sky, [170, 205, 215], 0.85) if dist(u, v, cx, cy, aspect) < 0.08 + 0.03 * brush(u, v, freq: 30.0)
          end
          return sky
        end
        # the red-brown paths with green verges
        if v > horizon + 0.03
          t = (v - horizon) / (1.0 - horizon)
          center = 0.52 - t * 0.02
          w = 0.01 + t * 0.10
          off = (u - center).abs
          return mix([190, 80, 40], [150, 60, 30], vnoise(u, v, 20.0)) if off < w
          return [60, 140, 60] if off < w + 0.015 + t * 0.03
          [[0.0, 0.70, 0.26, 0.50], [1.0, 0.66, 0.76, 0.48]].each do |ax, ay, bx, by|
            d = imp_seg(u, v, ax, ay, bx, by, aspect)
            return [180, 80, 40] if d < 0.03 && v > by
            return [70, 140, 60] if d < 0.055 && v > by
          end
        end
        # agitated wheat
        ang = 1.2 + (vnoise(u, v, 5.0) - 0.5) * 2.0
        st = brush(u, v, angle: ang, freq: 35.0, wobble: 0.8)
        wheat = if st > 0.5 then [245, 205, 80]
                elsif st < -0.6 then [170, 110, 20]
                else [220, 165, 40]
                end
        wheat = mix(wheat, [100, 140, 50], 0.5) if v < horizon + 0.05 && vnoise(u, v, 20.0) > 0.55
        wheat
      end

      # van Gogh, Bedroom in Arles
      def imp_bedroom_in_arles(u, v)
        bed_yellow = [230, 170, 60]
        # footboard at front right
        return mix(bed_yellow, [190, 130, 40], (u - 0.70) * 3) if u > 0.70 && v > 0.66 && v < 0.94 && v > 0.66 + (u - 0.70) * 0.05
        # mattress, red blanket, white pillows
        mattress = [[0.60, 0.44], [0.86, 0.44], [1.0, 0.66], [0.70, 0.68]]
        if inside?(u, v, mattress)
          return [245, 240, 205] if v < 0.50
          return mix([220, 60, 40], [180, 40, 30], vnoise(u, v, 12.0))
        end
        return bed_yellow if u > 0.60 && u < 0.86 && v > 0.27 && v < 0.46
        # chair by the bed and chair at front left
        [[0.52, 0.60, 0.8], [0.15, 0.80, 1.3]].each do |cx, cy, s|
          return [215, 175, 90] if ellipse(u, v, cx, cy, 0.06 * s, 0.025 * s) < 1
          return [200, 140, 50] if ((u - cx).abs - 0.05 * s).abs < 0.008 * s && v < cy && v > cy - 0.14 * s
          return [200, 140, 50] if (v - (cy - 0.12 * s)).abs < 0.008 * s && (u - cx).abs < 0.05 * s
          return [180, 120, 40] if ((u - cx).abs - 0.05 * s).abs < 0.008 * s && v > cy && v < cy + 0.09 * s
        end
        # small table with jug
        return [80, 110, 170] if ellipse(u, v, 0.28, 0.47, 0.012, 0.025) < 1
        return [210, 170, 100] if u > 0.20 && u < 0.36 && (v - 0.50).abs < 0.015
        return [180, 130, 70] if ((u - 0.22).abs < 0.006 || (u - 0.34).abs < 0.006) && v > 0.50 && v < 0.66
        # floor in tilted perspective
        floor_v = u < 0.22 ? 0.82 - u * 1.2 : 0.556 + (u > 0.72 ? (u - 0.72) * 0.6 : 0.0)
        if v > floor_v
          a = Math.atan2(v - 0.20, u - 0.45)
          base = mix([200, 120, 90], [170, 100, 80], v)
          return Math.sin(a * 40) > 0.75 ? [150, 150, 100] : base
        end
        # pictures on the walls
        [[0.66, 0.08, 0.04, 0.06], [0.78, 0.12, 0.04, 0.06], [0.90, 0.10, 0.05, 0.07], [0.25, 0.14, 0.03, 0.06]].each do |px, py, rx, ry|
          next unless (u - px).abs < rx && (v - py).abs < ry
          return [190, 150, 60] if (u - px).abs > rx * 0.7 || (v - py).abs > ry * 0.75
          return [200, 160, 110] if dist(u, v, px, py - ry * 0.2, 1.25) < rx * 0.5
          return [90, 140, 120]
        end
        # window with green shutters
        if u > 0.34 && u < 0.50 && v > 0.05 && v < 0.40
          return [70, 120, 60] if (u - 0.42).abs < 0.008 || (v - 0.20).abs < 0.008
          return [150, 190, 110]
        end
        return [70, 130, 80] if u > 0.30 && u < 0.54 && v > 0.03 && v < 0.42
        # left wall door, back wall, right wall
        return [100, 110, 170] if u < 0.13 && u > 0.03 && v > 0.12 && v < 0.75
        return [140, 150, 210] if u < 0.22
        return [120, 130, 195] if u > 0.72
        jitter([150, 165, 215], u, v, 6)
      end

      ALMOND_BRANCHES = [
        [0.00, 0.98, 0.28, 0.58, 0.035], [0.28, 0.58, 0.45, 0.36, 0.028], [0.45, 0.36, 0.63, 0.20, 0.022],
        [0.63, 0.20, 0.86, 0.04, 0.016], [0.28, 0.58, 0.14, 0.26, 0.018], [0.14, 0.26, 0.08, 0.02, 0.012],
        [0.14, 0.26, 0.32, 0.10, 0.011], [0.45, 0.36, 0.72, 0.46, 0.016], [0.72, 0.46, 0.97, 0.38, 0.011],
        [0.72, 0.46, 0.84, 0.78, 0.012], [0.84, 0.78, 0.92, 0.98, 0.010], [0.63, 0.20, 0.56, 0.02, 0.011]
      ].freeze
      ALMOND_BLOSSOMS = ALMOND_BRANCHES.each_with_index.flat_map do |(ax, ay, bx, by, _), i|
        [0.25, 0.55, 0.85].each_with_index.map do |t, j|
          side = (i + j).even? ? 1 : -1
          nx = -(by - ay)
          ny = bx - ax
          len = Math.hypot(nx, ny)
          [ax + (bx - ax) * t + side * nx / len * 0.035, ay + (by - ay) * t + side * ny / len * 0.035, (i * 3 + j) % 4]
        end
      end.freeze

      # van Gogh, Almond Blossoms
      def imp_almond_blossoms(u, v)
        aspect = 1.25
        ALMOND_BLOSSOMS.each do |bx, by, kind|
          d = dist(u, v, bx, by, aspect)
          next if d > 0.05
          a = Math.atan2(v - by, (u - bx) * aspect)
          r = (kind.zero? ? 0.025 : 0.04) * (0.75 + 0.25 * Math.cos(a * 5))
          next if d > r
          return [200, 70, 90] if d < r * 0.3
          return kind == 3 ? [245, 215, 220] : mix([255, 255, 250], [225, 235, 230], d / r)
        end
        ALMOND_BRANCHES.each do |ax, ay, bx, by, w|
          d = imp_seg(u, v, ax, ay, bx, by, aspect)
          return d < w * 0.4 ? [70, 80, 50] : [40, 50, 35] if d < w
        end
        sky = brush(u, v, angle: 0.6 + vnoise(u, v, 3.0), freq: 30.0) > 0.4 ? [140, 205, 210] : [100, 175, 195]
        jitter(sky, u, v, 8)
      end

      # van Gogh, Self-Portrait (1889)
      def imp_van_gogh_self_portrait(u, v)
        hair = [205, 110, 45]
        # blue suit with swirling strokes, white collar
        coat = [[0.12, 1.0], [0.16, 0.72], [0.32, 0.58], [0.50, 0.55], [0.68, 0.58], [0.84, 0.70], [0.90, 1.0]]
        if inside?(u, v, coat)
          return [235, 235, 220] if v < 0.66 && (u - 0.50).abs < (0.66 - v) * 0.7 && v > 0.55
          return [40, 60, 100] if ((u - 0.5).abs - (v - 0.55) * 0.3).abs < 0.012
          return brush(u, v, angle: 0.8 + vnoise(u, v, 4.0) * 2, freq: 35.0) > 0.3 ? [90, 120, 170] : [55, 80, 130]
        end
        return [200, 160, 110] if (u - 0.50).abs < 0.06 && v > 0.47 && v < 0.58
        # face in three-quarter view, beard and hair
        face = ellipse(u, v, 0.48, 0.34, 0.14, 0.17)
        if face < 1
          return [70, 90, 60] if ((u - 0.43).abs < 0.025 || (u - 0.55).abs < 0.022) && (v - 0.31).abs < 0.012
          return mix(hair, [170, 80, 35], vnoise(u, v, 30.0)) if v < 0.24 + (u - 0.48).abs * 0.2
          return mix(hair, [230, 140, 60], vnoise(u, v, 30.0)) if v > 0.41 - (u - 0.48).abs * 0.15
          return [170, 120, 80] if (u - 0.47).abs < 0.008 && v > 0.32 && v < 0.38
          return mix([230, 190, 130], [170, 150, 100], smooth(0.40, 0.62, u))
        end
        return [205, 160, 110] if ellipse(u, v, 0.625, 0.34, 0.02, 0.04) < 1
        # swirling pale blue background
        r = dist(u, v, 0.5, 0.35, 0.83)
        a = Math.atan2(v - 0.35, (u - 0.5) * 0.83)
        swirl = Math.sin(r * 60 + a * 4 + vnoise(u, v, 5.0) * 3)
        base = swirl > 0.3 ? [175, 205, 210] : [130, 175, 190]
        jitter(base, u, v, 8)
      end

      VICTOIRE_RIDGE = [[0.0, 0.45], [0.25, 0.38], [0.45, 0.30], [0.60, 0.20], [0.66, 0.22], [0.78, 0.36], [0.90, 0.40], [1.0, 0.43]].freeze

      # Cezanne, Mont Sainte-Victoire
      def imp_mont_sainte_victoire(u, v)
        ridge = VICTOIRE_RIDGE.each_cons(2).each do |(x0, y0), (x1, y1)|
          break y0 + (y1 - y0) * (u - x0) / (x1 - x0) if u <= x1
        end
        ridge = 0.43 unless ridge.is_a?(Float)
        px = u * 13 + v * 4
        py = v * 15 - u * 2
        n = noise(px.floor, py.floor)
        if v < ridge
          pal = [[120, 170, 175], [175, 205, 200], [100, 145, 180], [150, 190, 170], [200, 215, 210]]
          return pal[(n * pal.size).floor]
        end
        return [80, 90, 140] if v < ridge + 0.015
        if v < ridge + 0.13 - u * 0.04 && u > 0.35
          pal = [[130, 140, 175], [170, 160, 175], [190, 175, 170], [115, 125, 160]]
          return pal[(n * pal.size).floor]
        end
        # houses in the valley
        if v > 0.55 && v < 0.78 && noise(px.floor + 11, py.floor) > 0.82
          return py - py.floor < 0.35 ? [190, 90, 50] : [230, 190, 120]
        end
        pal = if v > 0.86 then [[40, 80, 50], [60, 100, 60], [90, 120, 70], [50, 70, 60]]
              else [[90, 140, 80], [130, 160, 80], [200, 165, 95], [110, 150, 110], [175, 150, 80], [70, 120, 80]]
              end
        pal[(n * pal.size).floor]
      end

      # Cezanne, The Card Players
      def imp_the_card_players(u, v)
        skin = [210, 150, 100]
        # bottle in the middle
        if (u - 0.5).abs < (v < 0.40 ? 0.012 : 0.03) && v > 0.28 && v < 0.58
          return [230, 230, 210] if (u - 0.49).abs < 0.006 && v > 0.40
          return [40, 50, 40]
        end
        # cards and hands
        return [240, 235, 215] if ellipse(u, v, 0.38, 0.54, 0.025, 0.025) < 1 || ellipse(u, v, 0.63, 0.54, 0.025, 0.025) < 1
        return skin if ellipse(u, v, 0.40, 0.58, 0.03, 0.022) < 1 || ellipse(u, v, 0.61, 0.58, 0.03, 0.022) < 1
        # table top and front
        if u > 0.30 && u < 0.70 && v > 0.58
          return [205, 155, 90] if v < 0.64
          return mix([170, 80, 40], [130, 60, 35], vnoise(u, v, 10.0))
        end
        # left man with pipe, blue-violet jacket
        return [245, 245, 235] if imp_seg(u, v, 0.31, 0.31, 0.37, 0.34) < 0.008
        return [55, 50, 50] if ellipse(u, v, 0.26, 0.17, 0.07, 0.05) < 1 && v < 0.19
        return [55, 50, 50] if (v - 0.185).abs < 0.012 && (u - 0.26).abs < 0.10
        return mix(skin, [160, 100, 60], (u - 0.20) * 6) if ellipse(u, v, 0.27, 0.26, 0.055, 0.075) < 1
        if inside?(u, v, [[0.13, 0.34], [0.33, 0.34], [0.42, 0.56], [0.40, 1.0], [0.04, 1.0], [0.08, 0.50]])
          return brush(u, v, angle: 1.2, freq: 30.0) > 0.4 ? [110, 105, 160] : [75, 70, 120]
        end
        # right man, hat and ochre jacket
        return [110, 95, 75] if ellipse(u, v, 0.75, 0.15, 0.06, 0.06) < 1 && v < 0.18
        return [110, 95, 75] if (v - 0.175).abs < 0.012 && (u - 0.75).abs < 0.09
        return mix([160, 100, 60], skin, (u - 0.70) * 6) if ellipse(u, v, 0.74, 0.25, 0.055, 0.075) < 1
        return [210, 200, 180] if (v - 0.32).abs < 0.012 && (u - 0.75).abs < 0.06
        if inside?(u, v, [[0.66, 0.33], [0.88, 0.33], [0.95, 0.50], [0.98, 1.0], [0.60, 1.0], [0.58, 0.56]])
          return brush(u, v, angle: 1.0, freq: 30.0) > 0.4 ? [200, 165, 100] : [165, 130, 80]
        end
        # warm brown wall
        wall = mix([160, 115, 70], [110, 95, 80], u)
        wall = mix(wall, [90, 70, 50], 0.35) if brush(u, v, angle: 0.9, freq: 25.0) > 0.6
        jitter(wall, u, v, 8)
      end

      TAHITI_LEFT = [[0.18, 0.40], [0.38, 0.40], [0.46, 0.66], [0.48, 0.86], [0.12, 0.88], [0.14, 0.62]].freeze
      TAHITI_RIGHT = [[0.60, 0.40], [0.80, 0.40], [0.88, 0.62], [0.96, 0.96], [0.52, 0.96], [0.56, 0.62]].freeze

      # Gauguin, Tahitian Women on the Beach
      def imp_tahitian_women(u, v)
        skin = [190, 120, 70]
        outline = [50, 35, 30]
        # left woman in profile: black hair, white top, red pareo with white flowers
        return [20, 15, 15] if ellipse(u, v, 0.29, 0.25, 0.07, 0.08) < 1 && u > 0.25
        return skin if ellipse(u, v, 0.26, 0.29, 0.045, 0.06) < 1
        return [250, 250, 240] if dist(u, v, 0.30, 0.20, 1.32) < 0.02
        return skin if imp_seg(u, v, 0.18, 0.45, 0.10, 0.70, 1.32) < 0.025
        if inside?(u, v, TAHITI_LEFT)
          return [240, 235, 220] if v < 0.56
          return [250, 245, 230] if noise((u * 30).floor, (v * 24).floor) > 0.72
          return [205, 40, 40]
        end
        return outline if imp_outline?(u, v, TAHITI_LEFT)
        # right woman, frontal, pink dress, weaving palm fronds
        return [20, 15, 15] if ellipse(u, v, 0.70, 0.24, 0.075, 0.08) < 1 && v < 0.27
        return skin if ellipse(u, v, 0.70, 0.29, 0.05, 0.07) < 1
        return skin if (u - 0.70).abs < 0.025 && v > 0.34 && v < 0.42
        if inside?(u, v, TAHITI_RIGHT)
          return [240, 210, 120] if ellipse(u, v, 0.70, 0.70, 0.10, 0.04) < 1
          return skin if ellipse(u, v, 0.70, 0.64, 0.07, 0.025) < 1
          return [250, 240, 230] if v < 0.45 && (u - 0.70).abs < 0.05
          return Math.sin(u * 50 + v * 10) > 0.6 ? [200, 100, 130] : [230, 140, 160]
        end
        return outline if imp_outline?(u, v, TAHITI_RIGHT)
        # flat sea band with a white wave line, then pink-ochre sand
        wave = 0.30 + 0.015 * Math.sin(u * 18)
        return [30, 70, 80] if v < 0.12
        return [60, 140, 130] if v < wave - 0.02
        return [225, 235, 225] if v < wave + 0.01
        sand = mix([225, 170, 140], [200, 130, 110], vnoise(u, v, 5.0))
        sand = mix(sand, [170, 100, 90], 0.4) if v > 0.80 && vnoise(u, v, 8.0) > 0.6
        sand
      end
    end

    piece(:impression_sunrise, "Impression, Sunrise", "Claude Monet", "1872", aspect: 1.31) { |u, v| imp_impression_sunrise(u, v) }
    piece(:water_lilies, "Water Lilies", "Claude Monet", "1906", aspect: 1.1) { |u, v| imp_water_lilies(u, v) }
    piece(:woman_with_a_parasol, "Woman with a Parasol", "Claude Monet", "1875", aspect: 0.81) { |u, v| imp_woman_with_a_parasol(u, v) }
    piece(:japanese_footbridge, "The Water Lily Pond (Japanese Footbridge)", "Claude Monet", "1899", aspect: 1.0) { |u, v| imp_japanese_footbridge(u, v) }
    piece(:poppy_field, "Poppy Field", "Claude Monet", "1873", aspect: 1.3) { |u, v| imp_poppy_field(u, v) }
    piece(:bal_du_moulin_de_la_galette, "Bal du moulin de la Galette", "Pierre-Auguste Renoir", "1876", aspect: 1.33) { |u, v| imp_bal_du_moulin(u, v) }
    piece(:the_dance_class, "The Dance Class", "Edgar Degas", "1874", aspect: 0.88) { |u, v| imp_the_dance_class(u, v) }
    piece(:sunday_on_la_grande_jatte, "A Sunday on La Grande Jatte", "Georges Seurat", "1886", aspect: 1.49) { |u, v| imp_grande_jatte(u, v) }
    piece(:bar_at_the_folies_bergere, "A Bar at the Folies-Bergère", "Édouard Manet", "1882", aspect: 1.35) { |u, v| imp_bar_folies(u, v) }
    piece(:luncheon_on_the_grass, "Luncheon on the Grass", "Édouard Manet", "1863", aspect: 1.27) { |u, v| imp_luncheon(u, v) }
    piece(:sunflowers, "Sunflowers", "Vincent van Gogh", "1888", aspect: 0.79) { |u, v| imp_sunflowers(u, v) }
    piece(:cafe_terrace_at_night, "Café Terrace at Night", "Vincent van Gogh", "1888", aspect: 0.81) { |u, v| imp_cafe_terrace(u, v) }
    piece(:wheatfield_with_crows, "Wheatfield with Crows", "Vincent van Gogh", "1890", aspect: 2.04) { |u, v| imp_wheatfield_with_crows(u, v) }
    piece(:bedroom_in_arles, "Bedroom in Arles", "Vincent van Gogh", "1888", aspect: 1.25) { |u, v| imp_bedroom_in_arles(u, v) }
    piece(:almond_blossoms, "Almond Blossoms", "Vincent van Gogh", "1890", aspect: 1.25) { |u, v| imp_almond_blossoms(u, v) }
    piece(:van_gogh_self_portrait, "Self-Portrait", "Vincent van Gogh", "1889", aspect: 0.83) { |u, v| imp_van_gogh_self_portrait(u, v) }
    piece(:mont_sainte_victoire, "Mont Sainte-Victoire", "Paul Cézanne", "c. 1904", aspect: 1.26) { |u, v| imp_mont_sainte_victoire(u, v) }
    piece(:the_card_players, "The Card Players", "Paul Cézanne", "c. 1893", aspect: 1.21) { |u, v| imp_the_card_players(u, v) }
    piece(:tahitian_women_on_the_beach, "Tahitian Women on the Beach", "Paul Gauguin", "1891", aspect: 1.32) { |u, v| imp_tahitian_women(u, v) }
  end
end
