# frozen_string_literal: true

module Dopairb
  module Gallery
    # Shared shape helpers for the pieces in this file.
    module ModernAncient
      module_function

      # Distance from (u, v) to the segment (x1, y1)-(x2, y2); sx scales the u axis.
      def seg(u, v, x1, y1, x2, y2, sx = 1.0)
        px = (u - x1) * sx
        py = v - y1
        dx = (x2 - x1) * sx
        dy = y2 - y1
        t = ((px * dx + py * dy) / (dx * dx + dy * dy + 1e-12)).clamp(0.0, 1.0)
        Math.hypot(px - dx * t, py - dy * t)
      end

      # Position along an Archimedean spiral arm, 0..1 (lines where it is small).
      def spiral(dx, dy, pitch, dir = 1)
        t = Math.hypot(dx, dy) / pitch - dir * Math.atan2(dy, dx) / (2 * Math::PI)
        t - t.floor
      end

      # Triangle wave 0..1..0 with period 1.
      def tri(x) = 1 - (x - x.floor - 0.5).abs * 2

      # A cave-painting horse facing left; s scales it, sx is the aspect.
      # => :body, :mane (dark parts) or nil
      def horse(u, v, x, y, s, sx)
        return :body if Paint.ellipse(u * sx, v, x * sx, y, 0.13 * s, 0.065 * s) < 1
        return :mane if seg(u, v, x - 0.045 * s, y - 0.03 * s, x - 0.075 * s, y - 0.085 * s, sx) < 0.028 * s
        return :mane if Paint.ellipse(u * sx, v, (x - 0.085 * s) * sx, y - 0.085 * s, 0.045 * s, 0.025 * s) < 1
        [[-0.05, -0.07], [-0.02, -0.04], [0.04, 0.02], [0.06, 0.08]].each do |a, b|
          return :mane if seg(u, v, x + a * s, y + 0.03 * s, x + b * s, y + 0.13 * s, sx) < 0.012 * s
        end
        return :mane if seg(u, v, x + 0.07 * s, y - 0.02 * s, x + 0.10 * s, y + 0.07 * s, sx) < 0.012 * s
        nil
      end

      # A tree of the Nebamun garden: trunk at the base, crown pointing away.
      def nebamun_tree(u, v, along, across, palm)
        return nil if along < -0.01 || along > 0.25 || across.abs > 0.08
        return [110, 70, 40] if along < 0.09 && across.abs < 0.008
        if palm
          return [180, 50, 40] if (across / 0.02)**2 + ((along - 0.10) / 0.02)**2 < 1
          fx = along - 0.09
          return nil if fx < 0 || fx > 0.13
          a = Math.atan2(across, fx)
          return [40, 90, 50] if a.abs < 1.1 && Math.sin(a * 9).abs > 0.4
          return nil
        end
        ce = (across / 0.055)**2 + ((along - 0.15) / 0.07)**2
        return nil if ce >= 1
        return [200, 60, 40] if Paint.noise((u * 60).floor, (v * 60).floor) > 0.82
        ce > 0.75 ? [30, 70, 40] : [60, 115, 60]
      end

      # A Bayeux figure at x; kind :seated, :oath or :stand.
      def bayeux_figure(u, v, x, c, kind, sx)
        olive = [120, 125, 65]
        y0 = kind == :seated ? 0.40 : 0.36
        return [205, 170, 140] if Paint.dist(u, v, x, y0, sx) < 0.045
        return c if seg(u, v, x, y0 + 0.06, x, y0 + 0.28, sx) < 0.05 && v < y0 + 0.32
        case kind
        when :seated
          return olive if (u - x).abs < 0.05 && v.between?(0.55, 0.72) && (u > x + 0.02 || v > 0.66)
          return c if seg(u, v, x, 0.66, x + 0.04, 0.78, sx) < 0.012
          return [80, 70, 60] if seg(u, v, x + 0.02, 0.52, x + 0.06, 0.34, sx) < 0.006 # sword
        when :oath
          return c if seg(u, v, x, y0 + 0.10, x - 0.06, y0 + 0.16, sx) < 0.013
          return c if seg(u, v, x, y0 + 0.10, x + 0.06, y0 + 0.16, sx) < 0.013
        else
          return c if seg(u, v, x, y0 + 0.10, x - 0.04, y0 + 0.04, sx) < 0.012
        end
        return c if v > y0 + 0.25 && ((u - x).abs - 0.008).abs < 0.006 && v < 0.79
        nil
      end
    end

    # Klimt, The Kiss
    piece :the_kiss, "The Kiss", "Gustav Klimt", "1908", aspect: 1.0 do |u, v|
      # her face, tilted on his shoulder, eyes closed
      if ellipse(u, v, 0.575, 0.31, 0.055, 0.042) < 1
        next [120, 80, 60] if (v - 0.302 - (u - 0.56) * 0.3).abs < 0.006 && (u - 0.555).abs < 0.016
        next [200, 90, 80] if ellipse(u, v, 0.605, 0.325, 0.01, 0.006) < 1
        next mix([248, 228, 205], [225, 190, 160], u - 0.55)
      end
      # her hair with flowers
      if ellipse(u, v, 0.635, 0.285, 0.045, 0.075) < 1
        next noise((u * 90).floor, (v * 90).floor) > 0.7 ? [235, 120, 90] : [120, 60, 30]
      end
      # his cheek and dark hair crowned with ivy
      next [210, 160, 120] if ellipse(u, v, 0.515, 0.22, 0.04, 0.05) < 1
      if ellipse(u, v, 0.47, 0.15, 0.07, 0.06) < 1
        next noise((u * 70).floor, (v * 70).floor) > 0.75 ? [90, 130, 60] : [25, 22, 20]
      end
      # her hand on his neck, her feet over the edge
      next [240, 210, 185] if ellipse(u, v, 0.505, 0.27, 0.022, 0.03) < 1
      next [235, 200, 170] if ellipse(u, v, 0.585, 0.935, 0.035, 0.022) < 1
      robe = [[0.38, 0.10], [0.58, 0.10], [0.72, 0.26], [0.77, 0.50], [0.72, 0.74], [0.63, 0.92],
              [0.50, 0.90], [0.33, 0.74], [0.26, 0.48], [0.29, 0.22]]
      if inside?(u, v, robe)
        if u < 0.55 - (v - 0.3) * 0.15
          # his robe: black, white and silver rectangles on gold
          cx = (u * 18).floor
          cy = (v * 9).floor
          lx = u * 18 - cx
          ly = v * 9 - cy
          n = noise(cx, cy)
          if lx.between?(0.15, 0.85) && ly.between?(0.08, 0.92) && n > 0.35
            next n > 0.75 ? [235, 230, 215] : (n > 0.55 ? [20, 18, 18] : [160, 160, 150])
          end
          next jitter([220, 175, 60], u, v, 20, 40)
        end
        # her dress: colourful circles
        cx = (u * 18).floor
        cy = (v * 18).floor
        n = noise(cx + 7, cy)
        if Math.hypot(u * 18 - cx - 0.5, v * 18 - cy - 0.5) < 0.38
          next [[200, 50, 50], [70, 90, 170], [150, 70, 140], [240, 140, 60], [235, 235, 220]][(n * 5).floor]
        end
        next jitter([210, 165, 60], u, v, 20, 40)
      end
      # flower meadow at the bottom left, dropping to the right
      meadow = [[0.0, 0.66], [0.25, 0.68], [0.50, 0.80], [0.64, 0.90], [0.70, 1.0], [0.0, 1.0]]
      if inside?(u, v, meadow)
        f = noise((u * 50).floor, (v * 50).floor)
        next [[230, 90, 80], [240, 200, 80], [150, 110, 190], [240, 240, 230]][(f * 40).floor % 4] if f > 0.72
        next jitter([60, 100, 55], u, v, 18, 25)
      end
      next [215, 175, 80] if noise((u * 64).floor, (v * 64).floor) > 0.88
      mix([140, 115, 50], [95, 80, 40], vnoise(u, v, 6))
    end

    # Klimt, The Tree of Life (Stoclet Frieze)
    piece :tree_of_life, "The Tree of Life", "Gustav Klimt", "1909", aspect: 1.9 do |u, v|
      x = u * 1.9
      brown = [140, 90, 35]
      gold = [205, 155, 50]
      # the black bird on top of the tree
      next [15, 15, 15] if ellipse(x, v, 0.95, 0.20, 0.035, 0.05) < 1 || ModernAncient.seg(x, v, 0.98, 0.16, 1.02, 0.15) < 0.01
      # trunk with eye motifs
      tw = 0.035 + (v - 0.4) * 0.05
      if v > 0.26 && (x - 0.95).abs < tw
        next [235, 225, 200] if ellipse(x, v, 0.95, ((v * 10).floor + 0.5) / 10, 0.015, 0.025) < 1 && v > 0.5
        next mix(brown, gold, Math.sin(v * 60) * 0.5 + 0.5)
      end
      # spiralling branches: scrolls hanging off two curving boughs
      scroll = nil
      [[0.20, 0.30, 1], [0.45, 0.22, -1], [0.70, 0.36, 1], [0.30, 0.62, -1], [0.58, 0.55, 1],
       [1.25, 0.30, -1], [1.48, 0.22, 1], [1.72, 0.36, -1], [1.62, 0.62, 1], [1.35, 0.55, -1],
       [0.10, 0.52, 1], [1.82, 0.55, -1], [0.82, 0.62, -1], [1.10, 0.66, 1]].each do |cx, cy, dir|
        dx = x - cx
        dy = v - cy
        r = Math.hypot(dx, dy)
        next if r > 0.14
        if ModernAncient.spiral(dx, dy, 0.05, dir) < 0.5
          scroll = mix(gold, [100, 60, 25], r * 7)
          break
        end
      end
      next scroll if scroll
      ax = (x - 0.95).abs
      bough = 0.42 + 0.10 * Math.sin(ax * 7)
      next brown if (v - bough).abs < 0.022 && ax < 0.9
      bough2 = 0.30 + 0.12 * Math.sin(ax * 5 + 1)
      next brown if (v - bough2).abs < 0.018 && ax.between?(0.05, 0.85)
      # flowers on the ground
      if v > 0.86
        n = noise((u * 70).floor, (v * 40).floor)
        next [[200, 70, 60], [90, 120, 170], [230, 200, 90]][(n * 30).floor % 3] if n > 0.7
        next jitter([200, 175, 110], u, v, 12, 30)
      end
      jitter(mix([238, 225, 185], [225, 200, 140], v), u, v, 10, 15)
    end

    # Klimt, Portrait of Adele Bloch-Bauer I
    piece :portrait_of_adele_bloch_bauer, "Portrait of Adele Bloch-Bauer I", "Gustav Klimt", "1907", aspect: 1.0 do |u, v|
      skin = [238, 222, 210]
      # face
      fe = ellipse(u, v, 0.50, 0.25, 0.055, 0.075)
      if fe < 1
        next [40, 30, 30] if (v - 0.235).abs < 0.008 && ((u - 0.50).abs - 0.022).abs < 0.012
        next [190, 70, 70] if ellipse(u, v, 0.50, 0.295, 0.015, 0.007) < 1
        next mix(skin, [210, 185, 175], fe)
      end
      # black hair
      next [25, 20, 22] if ellipse(u, v, 0.50, 0.19, 0.08, 0.08) < 1 && v < 0.26
      # neck with golden choker
      if (u - 0.50).abs < 0.028 && v.between?(0.30, 0.37)
        next v.between?(0.32, 0.345) ? [230, 190, 80] : skin
      end
      # pale shoulders and clasped hands
      next skin if ellipse(u, v, 0.50, 0.40, 0.13, 0.04) < 1
      if ellipse(u, v, 0.47, 0.50, 0.07, 0.035) < 1
        next ((u * 60).floor % 3).zero? ? [200, 175, 165] : skin
      end
      # green patch at the lower left
      if u < 0.26 + 0.05 * Math.sin(v * 10) && v > 0.74
        next noise((u * 50).floor, (v * 50).floor) > 0.8 ? [210, 180, 80] : jitter([70, 120, 75], u, v, 15, 20)
      end
      dress = [[0.36, 0.38], [0.64, 0.38], [0.70, 0.70], [0.80, 1.0], [0.22, 1.0], [0.30, 0.70]]
      if inside?(u, v, dress)
        # eye ornaments
        gy = v * 9
        row = gy.floor
        gx = u * 9 + (row.odd? ? 0.5 : 0.0)
        lx = gx - gx.floor - 0.5
        ly = gy - row - 0.5
        e = (lx / 0.38)**2 + (ly / 0.2)**2
        if e < 1
          next [20, 20, 20] if e < 0.18
          next e < 0.55 ? [240, 235, 215] : [120, 80, 30]
        end
        next jitter([225, 180, 60], u, v, 20, 40)
      end
      # background: gold with small squares and spirals
      cx = (u * 16).floor
      cy = (v * 16).floor
      lx = u * 16 - cx
      ly = v * 16 - cy
      n = noise(cx, cy)
      if n > 0.7 && lx.between?(0.2, 0.8) && ly.between?(0.2, 0.8)
        next n > 0.85 ? [150, 110, 40] : [210, 205, 180]
      end
      next [170, 120, 40] if u < 0.3 && v < 0.6 && ModernAncient.spiral(u - 0.15, v - 0.35, 0.04) < 0.2
      jitter([200, 160, 55], u, v, 22, 50)
    end

    # Henri Rousseau, The Sleeping Gypsy
    piece :the_sleeping_gypsy, "The Sleeping Gypsy", "Henri Rousseau", "1897", aspect: 1.55 do |u, v|
      sx = 1.55
      # the lion, sniffing from behind
      if ellipse(u, v, 0.53, 0.50, 0.035, 0.065) < 1
        next [30, 25, 20] if ellipse(u, v, 0.525, 0.475, 0.008, 0.012) < 1
        next [210, 170, 110]
      end
      next [125, 80, 45] if ellipse(u, v, 0.56, 0.47, 0.065, 0.14) < 1 && u < 0.595 # mane
      lion = [195, 155, 95]
      next lion if ellipse(u, v, 0.71, 0.50, 0.15, 0.085) < 1
      next lion if v.between?(0.52, 0.70) && [0.60, 0.645, 0.78, 0.825].any? { |lx| (u - lx).abs < 0.014 }
      next lion if ModernAncient.seg(u, v, 0.85, 0.48, 0.90, 0.33, sx) < 0.012
      next [110, 70, 40] if dist(u, v, 0.90, 0.32, sx) < 0.02
      # the sleeping woman in a striped robe
      if ellipse(u, v, 0.17, 0.75, 0.04, 0.05) < 1
        next u < 0.17 ? [25, 20, 20] : [90, 55, 40]
      end
      if ellipse(u, v, 0.44, 0.785, 0.25, 0.06) < 1
        s = (u * 30 + v * 20).floor % 5
        next [[200, 60, 50], [235, 150, 60], [230, 210, 120], [70, 100, 160], [235, 230, 210]][s]
      end
      next [80, 50, 35] if ellipse(u, v, 0.70, 0.81, 0.03, 0.015) < 1 # feet
      # mandolin and jug
      next [60, 35, 20] if ellipse(u, v, 0.48, 0.91, 0.022, 0.02) < 1
      next [190, 120, 50] if ellipse(u, v, 0.48, 0.91, 0.065, 0.045) < 1
      next [120, 70, 30] if u.between?(0.34, 0.42) && (v - 0.91).abs < 0.01
      next [175, 95, 55] if ellipse(u, v, 0.84, 0.82, 0.025, 0.05) < 1 || ellipse(u, v, 0.84, 0.765, 0.012, 0.02) < 1
      # moon
      next [235, 232, 205] if dist(u, v, 0.86, 0.13, sx) < 0.055
      # sand
      next jitter(mix([205, 180, 125], [175, 150, 100], (v - 0.6) * 2.5), u, v, 10, 25) if v > 0.585
      # river and far bank hills
      next mix([200, 205, 195], [160, 175, 175], Math.sin(u * 40) * 0.5 + 0.5) if v > 0.555
      hill = 0.47 + 0.04 * Math.sin(u * 7 + 1) + 0.02 * Math.sin(u * 17)
      next mix([170, 165, 150], [130, 130, 125], (v - hill) * 10) if v > hill
      mix([25, 50, 65], [90, 130, 130], smooth(0.0, 0.5, v))
    end

    # Henri Rousseau, Tiger in a Tropical Storm (Surprised!)
    piece :surprised, "Tiger in a Tropical Storm (Surprised!)", "Henri Rousseau", "1891", aspect: 1.25 do |u, v|
      sx = 1.25
      col = nil
      # the tiger crouching, facing left
      head = ellipse(u, v, 0.36, 0.58, 0.065, 0.075)
      body = ellipse(u, v, 0.52, 0.66, 0.17, 0.075)
      leg = [[0.37, 0.64, 0.33, 0.78], [0.42, 0.66, 0.40, 0.78], [0.62, 0.66, 0.62, 0.77], [0.66, 0.66, 0.69, 0.76]]
            .any? { |a, b, c, d| ModernAncient.seg(u, v, a, b, c, d, sx) < 0.022 }
      tail = ModernAncient.seg(u, v, 0.68, 0.64, 0.80, 0.56, sx) < 0.013 || ModernAncient.seg(u, v, 0.80, 0.56, 0.84, 0.47, sx) < 0.012
      if head < 1
        col = if ellipse(u, v, 0.34, 0.555, 0.012, 0.01) < 1 || ellipse(u, v, 0.385, 0.555, 0.012, 0.01) < 1
                [240, 230, 160]
              elsif ellipse(u, v, 0.34, 0.625, 0.03, 0.02) < 1
                [200, 60, 60]
              elsif ellipse(u, v, 0.33, 0.61, 0.045, 0.035) < 1
                [245, 235, 215]
              else
                Math.sin(v * 120) > 0.6 ? [30, 20, 15] : [230, 135, 45]
              end
      elsif body < 1 || leg || tail
        col = Math.sin(u * 90 + Math.sin(v * 25) * 2) > 0.45 ? [30, 20, 15] : mix([235, 145, 50], [245, 220, 170], (v - 0.64) * 8)
      end
      unless col
        lx = 0.80 + 0.06 * ModernAncient.tri(v * 6)
        if v < 0.4 && (u - lx).abs < 0.008
          col = [250, 250, 220] # lightning
        else
          # layered leaves: the topmost leaf of the 3x3 neighbouring cells wins
          gx = u * 8
          gy = v * 7
          best = -1.0
          (-1..1).each do |di|
            (-1..1).each do |dj|
              cx = gx.floor + di
              cy = gy.floor + dj
              n = noise(cx, cy)
              next if n < best
              ox = cx + 0.5 + (noise(cx + 9, cy) - 0.5) * 0.6
              oy = cy + 0.5 + (noise(cx, cy + 9) - 0.5) * 0.6
              a = noise(cx + 3, cy + 5) * Math::PI
              px = gx - ox
              py = gy - oy
              lx2 = px * Math.cos(a) + py * Math.sin(a)
              ly2 = -px * Math.sin(a) + py * Math.cos(a)
              e = (lx2 / 0.95)**2 + (ly2 / 0.32)**2
              next if e >= 1
              best = n
              greens = [[35, 85, 40], [80, 140, 55], [25, 60, 35], [120, 160, 60], [55, 110, 75], [150, 135, 55], [95, 125, 45]]
              g = greens[(noise(cx + 1, cy + 2) * greens.size).floor]
              col = ly2.abs < 0.04 || e > 0.75 ? Color.scale(g, 0.7) : g
            end
          end
          col ||= mix([140, 150, 130], [20, 40, 25], v * 2.5)
        end
      end
      # slanting rain
      r = u * 22 + v * 9
      (r - r.floor) < 0.07 ? mix(col, [210, 220, 220], 0.45) : col
    end

    # Malevich, Black Square
    piece :black_square, "Black Square", "Kazimir Malevich", "1915", aspect: 1.0 do |u, v|
      if u.between?(0.17, 0.83) && v.between?(0.17 + (u - 0.17) * 0.01, 0.83)
        next [120, 105, 80] if (vnoise(u, v, 9) - 0.5).abs < 0.018
        next [80, 70, 55] if (vnoise(u + 3, v, 17) - 0.5).abs < 0.02
        next jitter([22, 20, 18], u, v, 6, 20)
      end
      jitter(mix([238, 232, 215], [220, 210, 185], vnoise(u, v, 4)), u, v, 6, 30)
    end

    # Kandinsky, Composition VII
    piece :composition_vii, "Composition VII", "Wassily Kandinsky", "1913", aspect: 1.5 do |u, v|
      sx = 1.5
      ink = [20, 15, 20]
      # black lines whipping across
      waves = [[0.30, 0.12, 9, 0.0], [0.62, 0.08, 7, 1.5], [0.80, 0.10, 11, 3.0], [0.20, 0.06, 15, 2.0],
               [0.45, 0.15, 5, 4.0], [0.92, 0.04, 19, 1.0]]
      next ink if waves.any? { |a, b, f, ph| (v - (a + b * Math.sin(u * f + ph))).abs < 0.007 }
      next ink if ModernAncient.seg(u, v, 0.55, 0.15, 0.80, 0.90, sx) < 0.006
      next ink if ModernAncient.seg(u, v, 0.10, 0.85, 0.50, 0.05, sx) < 0.006
      # the dark vortex left of center
      d = dist(u, v, 0.40, 0.48, sx)
      if d < 0.17
        next [10, 10, 15] if d < 0.04
        a = Math.atan2(v - 0.48, (u - 0.40) * sx)
        next Math.sin(d * 70 - a * 3) > 0.2 ? [25, 20, 30] : mix([70, 40, 110], [180, 60, 50], vnoise(u, v, 12))
      end
      # colour blobs
      wob = (vnoise(u, v, 10) - 0.5) * 0.8 - 0.25
      blob = [[0.66, 0.28, 0.12, 0.16, [40, 70, 175]], [0.22, 0.72, 0.10, 0.14, [205, 40, 40]],
              [0.58, 0.70, 0.13, 0.10, [245, 205, 50]], [0.84, 0.66, 0.08, 0.13, [55, 150, 90]],
              [0.18, 0.24, 0.08, 0.11, [130, 60, 145]], [0.88, 0.22, 0.06, 0.09, [235, 125, 40]],
              [0.45, 0.16, 0.06, 0.07, [235, 150, 175]], [0.06, 0.50, 0.05, 0.12, [60, 120, 190]],
              [0.72, 0.90, 0.10, 0.06, [110, 60, 40]]].find { |cx, cy, rx, ry, _| ellipse(u, v, cx, cy, rx, ry) + wob < 1 }
      next blob[4] if blob
      ramp(vnoise(u, v, 4) * 0.6 + vnoise(u + 2, v, 11) * 0.4, [240, 220, 170], [150, 190, 215], [235, 170, 140], [180, 215, 150], [225, 200, 215])
    end

    # Kandinsky, Several Circles
    piece :several_circles, "Several Circles", "Wassily Kandinsky", "1926", aspect: 1.0 do |u, v|
      col = mix([35, 40, 70], [8, 8, 15], dist(u, v, 0.55, 0.55) * 1.8)
      halo = (dist(u, v, 0.36, 0.36) - 0.25).abs
      col = mix(col, [70, 110, 210], 0.5 * (1 - halo / 0.05)) if halo < 0.05
      [[0.36, 0.36, 0.22, [25, 30, 90], 0.95], [0.62, 0.60, 0.13, [205, 60, 60], 0.75],
       [0.54, 0.46, 0.08, [245, 205, 60], 0.75], [0.72, 0.30, 0.065, [90, 185, 140], 0.75],
       [0.30, 0.72, 0.09, [175, 80, 180], 0.7], [0.50, 0.78, 0.05, [240, 140, 60], 0.8],
       [0.78, 0.76, 0.075, [60, 150, 225], 0.7], [0.46, 0.28, 0.04, [235, 235, 220], 0.8],
       [0.18, 0.52, 0.035, [225, 90, 50], 0.8], [0.86, 0.50, 0.04, [205, 225, 90], 0.75],
       [0.64, 0.18, 0.03, [235, 100, 150], 0.8], [0.40, 0.56, 0.05, [60, 175, 190], 0.6],
       [0.70, 0.62, 0.03, [250, 250, 240], 0.8], [0.25, 0.25, 0.06, [60, 60, 150], 0.5]].each do |cx, cy, r, c, a|
        d = dist(u, v, cx, cy)
        col = mix(col, mix(c, Color.scale(c, 1.25), d / r), a) if d < r
      end
      col
    end

    # Matisse, Dance
    piece :the_dance, "Dance", "Henri Matisse", "1910", aspect: 1.5 do |u, v|
      sx = 1.5
      # five dancers in a ring: [x, y (hip), lean, size]
      figs = [[0.13, 0.48, -0.10, 1.15], [0.36, 0.30, 0.05, 0.95], [0.62, 0.30, -0.04, 0.9],
              [0.86, 0.45, 0.08, 1.05], [0.48, 0.68, -0.12, 1.1]]
      shoulders = figs.map { |x, y, l, s| [x + l * 0.6, y - 0.22 * s] }
      hit = figs.each_with_index.any? do |(x, y, l, s), i|
        hx, hy = shoulders[i]
        dist(u, v, hx + l * 0.25, hy - 0.07 * s, sx) < 0.055 * s ||
          ModernAncient.seg(u, v, x, y, hx, hy + 0.03, sx) < 0.06 * s ||
          ModernAncient.seg(u, v, x, y, x - 0.07 * s, y + 0.27 * s, sx) < 0.032 * s ||
          ModernAncient.seg(u, v, x, y, x + 0.08 * s, y + 0.24 * s, sx) < 0.032 * s
      end
      # linked arms around the ring, except the famous gap between the front pair
      hit ||= [[0, 1], [1, 2], [2, 3], [3, 4]].any? do |a, b|
        ax, ay = shoulders[a]
        bx, by = shoulders[b]
        mx = (ax + bx) / 2
        my = (ay + by) / 2 - 0.05
        ModernAncient.seg(u, v, ax, ay, mx, my, sx) < 0.024 || ModernAncient.seg(u, v, mx, my, bx, by, sx) < 0.024
      end
      fx, fy = shoulders[4]
      gx, gy = shoulders[0]
      hit ||= ModernAncient.seg(u, v, fx, fy, fx - 0.13, fy + 0.04, sx) < 0.024 || ModernAncient.seg(u, v, gx, gy, gx + 0.08, gy + 0.20, sx) < 0.024
      next jitter([215, 85, 50], u, v, 10, 20) if hit
      hill = 0.70 - 0.13 * Math.sin(Math::PI * (u * 0.9 + 0.08))
      next jitter([55, 145, 75], u, v, 10, 12) if v > hill
      jitter([35, 65, 155], u, v, 10, 12)
    end

    # Munch, Madonna
    piece :madonna_munch, "Madonna", "Edvard Munch", "1894", aspect: 0.76 do |u, v|
      skin = [236, 214, 190]
      hair = [18, 14, 16]
      # face, tilted back, eyes closed
      fe = ellipse(u, v, 0.50, 0.31, 0.12, 0.10)
      if fe < 1
        next [60, 40, 40] if ((u - 0.50).abs - 0.05).abs < 0.025 && (v - 0.30).abs < 0.008
        next [170, 60, 60] if ellipse(u, v, 0.50, 0.37, 0.02, 0.008) < 1
        next mix(skin, [200, 170, 150], fe * 0.8)
      end
      # red beret / halo
      next [205, 40, 40] if ellipse(u, v, 0.50, 0.215, 0.18, 0.05) < 1 && v < 0.235
      # neck and shoulders, cut off by the swirl below
      if v < 0.64 + 0.03 * Math.sin(u * 14)
        # long black hair flowing down both sides
        next hair if (u - (0.32 + 0.04 * Math.sin(v * 15))).abs < 0.07 && v > 0.24
        next hair if (u - (0.68 + 0.04 * Math.sin(v * 15 + 2))).abs < 0.06 && v > 0.24
        next hair if ellipse(u, v, 0.50, 0.28, 0.17, 0.10) < 1 && v < 0.3
        # raised arm behind the head
        next mix(skin, [205, 180, 160], 0.4) if ModernAncient.seg(u, v, 0.22, 0.60, 0.20, 0.30, 0.76) < 0.045
        next skin if (u - 0.50).abs < 0.06 && v.between?(0.38, 0.48)
        next mix(skin, [210, 185, 165], (v - 0.45) * 3) if ellipse(u, v, 0.50, 0.62, 0.28, 0.17) < 1
      end
      # swirling dark background
      d = Math.sqrt(ellipse(u, v, 0.50, 0.42, 0.45, 0.55)) + vnoise(u, v, 5) * 0.35
      s = Math.sin(d * 16 + Math.sin(Math.atan2(v - 0.45, u - 0.5) * 3) * 0.8)
      ramp(s * 0.5 + 0.5, [30, 25, 35], [25, 12, 18], [75, 18, 22], [130, 30, 30])
    end

    # Modigliani, Jeanne Hébuterne
    piece :portrait_of_jeanne_hebuterne, "Jeanne Hébuterne", "Amedeo Modigliani", "1918", aspect: 0.65 do |u, v|
      sx = 0.65
      th = 0.16
      du = (u - 0.52) * sx
      dv = v - 0.27
      x = du * Math.cos(th) + dv * Math.sin(th)
      y = -du * Math.sin(th) + dv * Math.cos(th)
      skin = [236, 196, 160]
      hair = [135, 60, 35]
      if (x / 0.095)**2 + (y / 0.15)**2 < 1 && y > -0.07
        next [85, 115, 125] if ((x.abs - 0.038) / 0.026)**2 + ((y + 0.01) / 0.011)**2 < 1 # almond eyes
        next [195, 70, 60] if (x / 0.022)**2 + ((y - 0.095) / 0.008)**2 < 1 # mouth
        next mix(skin, [200, 150, 115], 0.6) if x.between?(-0.004, 0.01) && y.between?(0.0, 0.06) # nose
        next mix(skin, [215, 160, 125], smooth(0.0, 0.1, -x) * 0.5)
      end
      # reddish-brown hair
      next jitter(hair, u, v, 15, 25) if (x / 0.12)**2 + ((y + 0.02) / 0.17)**2 < 1 && y < 0.08
      next jitter(hair, u, v, 15, 25) if ((x - 0.085) / 0.04)**2 + ((y - 0.12) / 0.10)**2 < 1
      # long neck, leaning with the head
      nc = 0.50 - (v - 0.40) * 0.12
      if (u - nc).abs < 0.065 && v.between?(0.38, 0.66)
        next mix(skin, [210, 160, 125], ((u - nc) / 0.065 + 1) * 0.4)
      end
      # dark dress with sloping shoulders
      shoulder = 0.60 + 0.5 * (u - 0.49).abs**1.3
      if v > shoulder
        next [225, 220, 205] if v < shoulder + 0.03 && (u - 0.49).abs < 0.2 && v < 0.72
        next jitter([40, 40, 55], u, v, 10, 15)
      end
      # warm ochre background, darker door at the left
      next jitter([140, 85, 50], u, v, 12, 15) if u < 0.18
      jitter(mix([215, 150, 75], [190, 120, 60], v), u, v, 14, 12)
    end

    # Paul Klee, Senecio
    piece :senecio, "Senecio", "Paul Klee", "1922", aspect: 0.94 do |u, v|
      sx = 0.94
      d = dist(u, v, 0.50, 0.46, sx)
      if d < 0.40
        # eyes: a red square and a red dot
        next [210, 40, 40] if (u - 0.37).abs < 0.03 && (v - 0.42).abs < 0.03
        next [240, 230, 210] if (u - 0.37).abs < 0.06 && (v - 0.42).abs < 0.055
        next [200, 40, 40] if dist(u, v, 0.63, 0.43, sx) < 0.03
        next [245, 235, 215] if dist(u, v, 0.63, 0.43, sx) < 0.055
        # raised eyebrow arc and the nose / mouth lines
        next [140, 70, 40] if (dist(u, v, 0.43, 0.42, sx) - 0.13).abs < 0.01 && v < 0.38
        next [150, 80, 50] if (u - 0.50).abs < 0.008 && v.between?(0.36, 0.58)
        next [150, 80, 50] if (v - 0.62).abs < 0.008 && (u - 0.50).abs < 0.06
        next [190, 100, 60] if (d - 0.39).abs < 0.012
        # flat geometric blocks
        cx = ((u - 0.10) / 0.2).floor
        cy = ((v - 0.06) / 0.16).floor
        pal = [[240, 170, 80], [245, 200, 120], [235, 140, 90], [245, 210, 170], [230, 120, 60], [240, 185, 150]]
        c = pal[(noise(cx + 4, cy + 2) * pal.size).floor]
        c = mix(c, [250, 235, 210], 0.35) if u < 0.5 && v < 0.55
        next jitter(c, u, v, 8, 20)
      end
      # neck and shoulders at the bottom
      next [235, 175, 120] if v > 0.84 && (u - 0.5).abs < 0.12
      next [215, 110, 60] if v > 0.92
      jitter(mix([215, 120, 55], [195, 95, 45], v), u, v, 10, 20)
    end

    # Mondrian, Composition with Red, Blue and Yellow
    piece :composition_with_red_blue_yellow, "Composition with Red, Blue and Yellow", "Piet Mondrian", "1930", aspect: 1.0 do |u, v|
      w = 0.022
      line = (u - 0.30).abs < w || (v - 0.70).abs < w ||
             (u < 0.30 && (v - 0.36).abs < w) ||
             (v > 0.70 && (u - 0.92).abs < w * 0.8) ||
             (u > 0.92 && (v - 0.86).abs < w * 0.8)
      next [20, 20, 25] if line
      next [220, 35, 30] if u > 0.30 && v < 0.70
      next [30, 50, 150] if u < 0.30 && v > 0.70
      next [245, 215, 50] if u > 0.92 && v > 0.86
      [240, 238, 230]
    end

    # Hilma af Klint, The Ten Largest, No. 7, Adulthood
    piece :the_ten_largest_no7, "The Ten Largest, No. 7, Adulthood", "Hilma af Klint", "1907", aspect: 0.75 do |u, v|
      sx = 0.75
      # big yellow spiral
      dx = (u - 0.40) * sx
      dy = v - 0.30
      next [250, 225, 110] if Math.hypot(dx, dy) < 0.20 && ModernAncient.spiral(dx, dy, 0.045) < 0.35
      # rosettes: [cx, cy, radius, petals, colour, centre colour]
      petal = nil
      [[0.68, 0.58, 0.16, 8, [165, 200, 230], [250, 230, 140]],
       [0.28, 0.74, 0.13, 6, [250, 230, 140], [230, 110, 120]],
       [0.78, 0.18, 0.09, 5, [240, 200, 215], [120, 150, 200]],
       [0.22, 0.12, 0.06, 4, [165, 200, 230], [250, 250, 240]],
       [0.60, 0.88, 0.07, 6, [240, 200, 215], [165, 200, 230]]].each do |cx, cy, rad, n, c, cc|
        ex = (u - cx) * sx
        ey = v - cy
        rr = Math.hypot(ex, ey)
        next if rr > rad
        if rr < rad * 0.3
          petal = cc
        elsif rr < rad * (0.55 + 0.45 * Math.cos(Math.atan2(ey, ex) * n / 2.0).abs)
          petal = c
        end
        break if petal
      end
      next petal if petal
      # lettering-like curls
      next [90, 60, 80] if u < 0.45 && (v - 0.47 - 0.015 * Math.sin(u * 70)).abs < 0.005
      next [90, 60, 80] if v > 0.92 && u > 0.1 && ModernAncient.spiral((u * 30 % 1 - 0.5) * 0.04, v - 0.955, 0.008) < 0.25
      # soft pale blue forms
      next [190, 215, 230] if ellipse(u, v, 0.15, 0.50, 0.10, 0.07) + (vnoise(u, v, 12) - 0.5) * 0.5 < 1
      jitter(mix([238, 150, 110], [230, 135, 100], v), u, v, 10, 15)
    end

    # Lascaux cave, the Hall of the Bulls
    piece :lascaux_horses, "Lascaux Cave Paintings (Horses and Aurochs)", "unknown artists", "c. 17,000 BC", aspect: 1.8 do |u, v|
      sx = 1.8
      rock = ramp(vnoise(u, v, 5) * 0.7 + vnoise(u, v, 17) * 0.3, [140, 100, 65], [200, 165, 115], [230, 205, 160])
      rock = Color.scale(rock, 0.65 + 0.35 * smooth(0.0, 0.35, v) - 0.25 * smooth(0.8, 1.0, v))
      black = [30, 22, 18]
      # the great aurochs
      be = ellipse(u * sx, v, 0.55 * sx, 0.38, 0.30, 0.13)
      next black if ellipse(u * sx, v, 0.33 * sx, 0.34, 0.06, 0.065) < 1
      next black if be.between?(0.72, 1.0)
      next black if be < 1 && noise((u * 50).floor, (v * 30).floor) > 0.9
      next black if ModernAncient.seg(u, v, 0.32, 0.29, 0.29, 0.15, sx) < 0.012 || ModernAncient.seg(u, v, 0.35, 0.29, 0.40, 0.16, sx) < 0.012
      legs = [[0.42, 0.48, 0.41, 0.66], [0.47, 0.50, 0.48, 0.66], [0.64, 0.48, 0.66, 0.64], [0.68, 0.46, 0.72, 0.62]]
      next black if legs.any? { |a, b, c, d| ModernAncient.seg(u, v, a, b, c, d, sx) < 0.016 }
      next black if ModernAncient.seg(u, v, 0.71, 0.36, 0.75, 0.55, sx) < 0.008
      next mix(rock, [235, 215, 175], 0.3) if be < 1
      # horses
      horse = nil
      [[0.15, 0.68, 1.0, [150, 60, 35]], [0.84, 0.72, 0.9, [90, 55, 30]], [0.55, 0.82, 0.6, [175, 80, 40]],
       [0.90, 0.30, 0.6, [120, 70, 40]]].each do |x, y, s, c|
        part = ModernAncient.horse(u, v, x, y, s, sx)
        next unless part
        horse = part == :body ? mix(c, [205, 150, 90], smooth(y, y + 0.06 * s, v)) : black
        break
      end
      next horse if horse
      # dots
      dots = [[0.62, 0.15], [0.65, 0.15], [0.68, 0.15], [0.71, 0.15], [0.10, 0.30], [0.12, 0.33], [0.36, 0.86], [0.39, 0.86]]
      next [60, 30, 20] if dots.any? { |x, y| dist(u, v, x, y, sx) < 0.018 }
      # cracks
      next Color.scale(rock, 0.7) if (vnoise(u + 5, v, 6) - 0.5).abs < 0.012
      rock
    end

    # Tomb of Nebamun, Pool in a Garden
    piece :garden_of_nebamun, "Pool in a Garden (Tomb of Nebamun)", "unknown Egyptian artist", "c. 1350 BC", aspect: 0.86 do |u, v|
      sx = 0.86
      # the pool, seen from above
      if u.between?(0.27, 0.73) && v.between?(0.30, 0.70)
        next [60, 45, 35] if u < 0.285 || u > 0.715 || v < 0.315 || v > 0.685
        # ducks and fish
        if [[0.40, 0.42], [0.58, 0.58]].any? { |x, y| ellipse(u, v, x, y, 0.045, 0.025) < 1 }
          next [235, 230, 215]
        end
        next [120, 80, 50] if [[0.40, 0.42], [0.58, 0.58]].any? { |x, y| ellipse(u, v, x - 0.05, y - 0.02, 0.015, 0.013) < 1 }
        next [190, 150, 130] if [[0.58, 0.40], [0.40, 0.60], [0.50, 0.50]].any? { |x, y| ellipse(u, v, x, y, 0.04, 0.015) < 1 }
        # lotus flowers along the edge
        if (u < 0.33 || u > 0.67 || v < 0.36 || v > 0.64) && noise((u * 40).floor, (v * 40).floor) > 0.6
          next noise((u * 40).floor + 1, (v * 40).floor) > 0.5 ? [240, 240, 230] : [70, 130, 120]
        end
        w = v * 22 + ModernAncient.tri(u * 25) * 0.4
        next (w - w.floor) < 0.18 ? [30, 45, 80] : [70, 115, 170]
      end
      # rows of trees laid flat around the pool, pointing away from it
      trees = []
      5.times { |i| trees << [0.25 + i * 0.125, 0.27, 0.0, -1.0, i.odd?] }
      5.times { |i| trees << [0.25 + i * 0.125, 0.73, 0.0, 1.0, i.even?] }
      3.times { |i| trees << [0.25, 0.38 + i * 0.12, -1.0, 0.0, i.odd?] }
      3.times { |i| trees << [0.75, 0.38 + i * 0.12, 1.0, 0.0, i.even?] }
      tree = nil
      trees.each do |bx, by, ddx, ddy, palm|
        px = (u - bx) * sx
        py = v - by
        tree = ModernAncient.nebamun_tree(u, v, px * ddx + py * ddy, px * ddy - py * ddx, palm)
        break if tree
      end
      next tree if tree
      jitter([226, 205, 165], u, v, 10, 20)
    end

    # The Bayeux Tapestry, Harold's oath to William
    piece :bayeux_tapestry, "Bayeux Tapestry (Harold's Oath)", "unknown embroiderers", "c. 1070", aspect: 2.6 do |u, v|
      sx = 2.6
      terra = [175, 90, 60]
      olive = [120, 125, 65]
      blue = [85, 105, 130]
      linen = jitter([236, 224, 192], u, v, 8, 40)
      # border lines and the borders with small beasts
      next [120, 90, 70] if (v - 0.17).abs < 0.008 || (v - 0.83).abs < 0.008
      if v < 0.17 || v > 0.83
        bv = v < 0.17 ? v / 0.17 : (v - 0.83) / 0.17
        k = u * 30 - bv * 0.6
        cell = k.floor
        lx = k - cell
        next [terra, olive, blue][cell % 3] if lx < 0.12
        next [olive, terra][(cell / 2) % 2] if cell.even? && ellipse(lx, bv, 0.55, 0.5, 0.22, 0.17) < 1
        next linen
      end
      # Latin inscription along the top
      if v.between?(0.21, 0.29) && u.between?(0.08, 0.92)
        lx = u * 70
        li = lx.floor
        f = lx - li
        n = noise(li, 3)
        next [55, 65, 95] if n > 0.15 && (f < 0.3 || (n > 0.6 && (v - 0.25).abs < 0.012 && f < 0.7))
        next linen
      end
      # William on his throne, Harold swearing, two witnesses
      fig = nil
      [[0.14, blue, :seated], [0.21, olive, :stand], [0.44, terra, :oath], [0.60, olive, :stand],
       [0.655, blue, :stand], [0.71, terra, :stand]].each do |x, c, kind|
        fig = ModernAncient.bayeux_figure(u, v, x, c, kind, sx)
        break if fig
      end
      next fig if fig
      # two reliquaries Harold swears on
      [0.375, 0.505].each do |x|
        fig = [200, 160, 80] if (u - x).abs < 0.02 && v.between?(0.53, 0.62)
        fig = blue if (u - x).abs < 0.005 && v.between?(0.62, 0.79)
      end
      next fig if fig
      # a building at the left and a horse at the right
      next [terra, olive][(u * 80).floor % 2] if u.between?(0.02, 0.06) && v.between?(0.32, 0.80)
      next terra if u < 0.08 && v.between?(0.30, 0.34)
      next olive if ellipse(u, v, 0.86, 0.55, 0.06, 0.09) < 1
      next olive if ModernAncient.seg(u, v, 0.81, 0.52, 0.78, 0.40, sx) < 0.02 || dist(u, v, 0.77, 0.40, sx) < 0.03
      next olive if v.between?(0.60, 0.79) && [0.82, 0.84, 0.88, 0.90].any? { |x| (u - x).abs < 0.004 }
      # a stylized tree between scenes
      next olive if ModernAncient.seg(u, v, 0.28, 0.79, 0.28, 0.45, sx) < 0.006
      next [terra, olive][(v * 40).floor % 2] if ellipse(u, v, 0.28, 0.42, 0.025, 0.08) < 1
      linen
    end

    # Pompeii, the Alexander Mosaic
    piece :alexander_mosaic, "Alexander Mosaic", "unknown, Pompeii", "c. 100 BC", aspect: 1.86 do |u, v|
      sx = 1.86
      # lost areas show bare plaster
      lost = (u < 0.42 && vnoise(u, v, 5) + (0.42 - u) * 0.6 > 0.82) || (v > 0.86 && u < 0.3 && vnoise(u, v, 9) > 0.45)
      next jitter([195, 182, 158], u, v, 6, 30) if lost && dist(u, v, 0.22, 0.34, sx) >= 0.08
      # tesserae: quantize to tiles
      nx = 80
      ny = 43
      iu = (u * nx).floor
      iv = (v * ny).floor
      shade = 0.88 + noise(iu, iv) * 0.2
      shade *= 0.85 if u * nx - iu < 0.12 || v * ny - iv < 0.12
      tu = (iu + 0.5) / nx
      tv = (iv + 0.5) / ny
      wheel = dist(tu, tv, 0.71, 0.66, sx)
      col =
        if dist(tu, tv, 0.22, 0.30, sx) < 0.045 then [205, 160, 120] # Alexander's head
        elsif ellipse(tu, tv, 0.23, 0.42, 0.04, 0.09) < 1 then [130, 125, 115] # armour
        elsif ellipse(tu, tv, 0.20, 0.60, 0.10, 0.11) < 1 || ModernAncient.seg(tu, tv, 0.26, 0.55, 0.31, 0.42, sx) < 0.04
          [95, 60, 35] # Bucephalus
        elsif dist(tu, tv, 0.70, 0.27, sx) < 0.04 then [195, 150, 110] # Darius
        elsif ModernAncient.seg(tu, tv, 0.68, 0.33, 0.60, 0.28, sx) < 0.015 then [195, 150, 110] # his outstretched arm
        elsif ellipse(tu, tv, 0.71, 0.38, 0.04, 0.07) < 1 then [120, 50, 70]
        elsif dist(tu, tv, 0.80, 0.28, sx) < 0.035 then [190, 145, 110] # charioteer
        elsif ellipse(tu, tv, 0.80, 0.38, 0.035, 0.07) < 1 then [130, 90, 60]
        elsif (wheel - 0.09).abs < 0.015 || (wheel < 0.09 && Math.sin(Math.atan2(tv - 0.66, tu - 0.71) * 6).abs < 0.15)
          [50, 35, 25] # chariot wheel
        elsif tu.between?(0.62, 0.84) && tv.between?(0.44, 0.58) then [110, 70, 40] # chariot box
        elsif ellipse(tu, tv, 0.90, 0.62, 0.09, 0.10) < 1 || ModernAncient.seg(tu, tv, 0.94, 0.58, 0.99, 0.45, sx) < 0.03
          [35, 30, 28] # black horses
        elsif ellipse(tu, tv, 0.48, 0.70, 0.09, 0.12) < 1 then [140, 90, 50] # Persian horse from behind
        elsif ellipse(tu, tv, 0.52, 0.52, 0.03, 0.08) < 1 then [170, 130, 90]
        elsif (tu - (0.33 + (0.6 - tv) * 0.05)).abs < 0.008 && tv.between?(0.08, 0.5) then [80, 70, 55] # bare tree
        elsif ModernAncient.seg(tu, tv, 0.33, 0.20, 0.27, 0.08, sx) < 0.008 then [80, 70, 55]
        elsif tv.between?(0.02, 0.55) && tu.between?(0.40, 0.90) && (((tu + (0.55 - tv) * 0.35) * 20) % 1) < 0.25
          [45, 35, 28] # forest of spears
        elsif tv > 0.80 && noise((tu * 20).floor, (tv * 12).floor) > 0.7 then [160, 40, 35] # fallen shields
        elsif tv > 0.56 then [150, 110, 70] # ground
        else [215, 190, 150]
        end
      Color.scale(col, shade)
    end

    # Ravenna, San Vitale: Emperor Justinian and His Retinue
    piece :justinian_mosaic, "Emperor Justinian and His Retinue", "unknown, Ravenna", "c. 547", aspect: 1.7 do |u, v|
      sx = 1.7
      nx = 85
      ny = 50
      iu = (u * nx).floor
      iv = (v * ny).floor
      shade = 0.85 + noise(iu, iv) * 0.25
      shade *= 0.88 if u * nx - iu < 0.12 || v * ny - iv < 0.12
      # jewelled border at the top
      next Color.scale((u * 30).floor.even? ? [40, 90, 80] : [120, 40, 60], shade) if v < 0.06
      col = nil
      # green shield with a chi-rho among the guards at the left
      if ellipse(u, v, 0.13, 0.62, 0.05, 0.14) < 1
        col = (u - 0.13).abs < 0.006 || (v - 0.62).abs < 0.008 ? [230, 200, 90] : [40, 110, 70]
      end
      9.times do |i|
        break if col
        x = 0.10 + i * 0.10
        emperor = i == 4
        hd = dist(u, v, x, 0.22, sx)
        if emperor && (hd - 0.11).abs < 0.01
          col = [120, 80, 30]
        elsif emperor && hd < 0.11 && hd >= 0.065
          col = [250, 215, 100]
        elsif hd < 0.065
          col = if v >= 0.195 then [225, 180, 150]
                elsif emperor then [230, 200, 80]
                else [60, 40, 30]
                end
        elsif (u - x).abs < 0.036 + (v - 0.30) * 0.04 && v.between?(0.30, 0.86)
          cloak = [3, 5].include?(i) && u < x
          col = if emperor
                  v > 0.36 && v < 0.5 && (u - x + 0.015).abs < 0.015 ? [230, 190, 80] : [110, 40, 95]
                elsif cloak then [175, 130, 80]
                elsif ((u - x).abs - 0.018).abs < 0.003 then [150, 110, 110]
                elsif i > 6 && v < 0.5 then [210, 190, 110]
                else [235, 230, 215]
                end
        elsif v.between?(0.86, 0.89) && ((u - x).abs - 0.015).abs < 0.01
          col = [30, 25, 25]
        end
      end
      col ||= v > 0.86 ? [60, 115, 60] : (noise(iu + 3, iv) > 0.8 ? [250, 220, 120] : [215, 170, 60])
      Color.scale(col, shade)
    end
  end
end
