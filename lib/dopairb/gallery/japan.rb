# frozen_string_literal: true

module Dopairb
  module Gallery
    # Distance from (px, py) to the segment (ax, ay)-(bx, by); pass aspect-scaled x.
    JP_SEG = lambda do |px, py, ax, ay, bx, by|
      dx = bx - ax
      dy = by - ay
      t = (((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy + 1e-12)).clamp(0.0, 1.0)
      Math.hypot(px - ax - t * dx, py - ay - t * dy)
    end

    # The color a feature loop produced with `break color`, or nil when it ran out.
    JP_HIT = ->(r) { r if r.is_a?(Array) && r.size == 3 && r[0].is_a?(Integer) }

    # Triangle wave 0..1..0 with period 1.
    JP_TRI = ->(x) { 1.0 - (x - x.floor - 0.5).abs * 2 }

    # Approximate signed distance to a rotated ellipse, all in aspect-scaled units.
    JP_RING = lambda do |x, y, cx, cy, rx, ry, ang = 0.0|
      dx = x - cx
      dy = y - cy
      c = Math.cos(ang)
      s = Math.sin(ang)
      ex = dx * c + dy * s
      ey = -dx * s + dy * c
      (Math.sqrt((ex / rx)**2 + (ey / ry)**2) - 1.0) * [rx, ry].min
    end

    # Tohaku's pine groves: [x, top, ink density, lean, [[dy, dx, rx] needle blots]]
    JP_PINES = [
      [0.07, 0.14, 0.55, 0.03, [[0.02, 0.01, 0.04], [0.14, -0.02, 0.05], [0.27, 0.02, 0.045]]],
      [0.13, 0.30, 0.30, -0.02, [[0.0, 0.0, 0.035], [0.12, 0.015, 0.045]]],
      [0.29, 0.04, 1.00, 0.04, [[0.0, 0.0, 0.045], [0.10, -0.03, 0.06], [0.22, 0.025, 0.07], [0.36, -0.02, 0.06]]],
      [0.36, 0.18, 0.80, -0.03, [[0.0, 0.01, 0.04], [0.12, 0.03, 0.06], [0.25, -0.02, 0.05]]],
      [0.44, 0.32, 0.45, 0.02, [[0.0, 0.0, 0.04], [0.11, -0.02, 0.05]]],
      [0.62, 0.12, 0.40, -0.02, [[0.0, 0.0, 0.04], [0.13, 0.02, 0.055], [0.27, -0.02, 0.05]]],
      [0.68, 0.28, 0.25, 0.03, [[0.0, 0.0, 0.035], [0.12, 0.02, 0.045]]],
      [0.86, 0.10, 0.18, 0.02, [[0.0, 0.0, 0.04], [0.14, -0.02, 0.05], [0.28, 0.02, 0.045]]],
      [0.94, 0.26, 0.10, -0.02, [[0.0, 0.0, 0.035], [0.12, 0.01, 0.04]]]
    ].freeze

    # Hokusai, Thunderstorm Beneath the Summit
    piece :thunderstorm_beneath_the_summit, "Thunderstorm Beneath the Summit", "Katsushika Hokusai", "c. 1831", aspect: 1.45 do |u, v|
      pu = 0.62
      pv = 0.13
      d = u - pu
      slope = pv + d.abs * (d < 0 ? 0.95 : 0.80) - d * d * 0.25
      if v >= slope
        base_line = 0.56 + 0.04 * Math.sin(u * 11) + 0.02 * Math.sin(u * 37)
        if v > base_line
          # the lightning bolt crackling over the dark foot
          lx = 0.70 + (v - 0.62) * 0.55 + 0.05 * (JP_TRI.((v - 0.6) * 7) - 0.5)
          next [240, 70, 35] if v > 0.62 && v < 0.97 && (u - lx).abs < 0.014
          next jitter([32, 26, 24], u, v, 8, 20)
        end
        # snow streaks running down from the summit
        reach = pv + 0.07 + 0.10 * vnoise(u, 0.3, 30)
        next mix([250, 248, 240], [215, 215, 225], (v - pv) * 5) if v < reach && Math.sin(u * 95) > -0.2
        next [250, 248, 240] if v < pv + 0.03
        base = mix([150, 55, 30], [95, 35, 25], smooth(0.2, 0.55, v))
        streak = Math.sin(u * 120 + v * 15) > 0.7 ? 0.8 : 1.0
        next Color.scale(jitter(base, u, v, 10), streak)
      end
      sky = mix([30, 75, 160], [195, 215, 230], smooth(0.0, 0.75, v))
      # billowing clouds low on the left and right
      cl = vnoise(u, v, 9) + smooth(0.25, 0.65, v) * 0.6 - 0.45
      if cl > 0.35 && (u < 0.42 || u > 0.85)
        next mix([255, 255, 250], [205, 210, 220], (cl - 0.35) * 0.5 + (v - 0.3))
      end
      sky
    end

    # Hokusai, Ejiri in Suruga Province
    piece :ejiri_in_suruga, "Ejiri in Suruga Province", "Katsushika Hokusai", "c. 1831", aspect: 1.45 do |u, v|
      x = u * 1.45
      # sheets of paper whirling across the sky
      papers = [[0.08, 0.55], [0.20, 0.42], [0.30, 0.30], [0.45, 0.36], [0.52, 0.22], [0.66, 0.30], [0.74, 0.16],
                [0.88, 0.24], [0.98, 0.12], [0.60, 0.46], [0.38, 0.18], [1.10, 0.20]]
      hit = JP_HIT.(papers.each_with_index do |(px, py), i|
        a = i * 1.3
        dx = x - px
        dy = v - py
        rx = dx * Math.cos(a) + dy * Math.sin(a)
        ry = -dx * Math.sin(a) + dy * Math.cos(a)
        next unless rx.abs < 0.022 && ry.abs < 0.016
        break rx.abs > 0.016 || ry.abs > 0.011 ? [150, 140, 120] : [252, 250, 240]
      end)
      next hit if hit
      # a hat tumbling up high
      next [175, 135, 70] if ellipse(u, v, 0.56, 0.12, 0.022, 0.018) < 1
      # bent trees on the right
      hit = JP_HIT.([[0.78, 0.0], [0.86, 0.03], [0.70, 0.05]].each do |tx, off|
        cx = tx - 0.22 * (0.92 - v)**2 + off
        break [70, 55, 40] if v > 0.18 + off * 2 && v < 0.92 && (u - cx).abs < 0.008 + (v - 0.2) * 0.008
        if v > 0.12 && v < 0.5 && ellipse(u, v, cx - 0.05, 0.22 + off * 3, 0.07, 0.05) < 1 && vnoise(u, v, 30) > 0.5
          break [70, 95, 60]
        end
      end)
      next hit if hit
      # travelers bending into the wind along the path
      hit = JP_HIT.([[0.18, 0.80], [0.30, 0.82], [0.42, 0.79], [0.55, 0.83], [0.64, 0.80]].each do |fx, fy|
        next unless (u - fx).abs < 0.03 && v > fy - 0.10 && v < fy + 0.04
        break [180, 140, 70] if ellipse(u, v, fx + 0.012, fy - 0.075, 0.022, 0.02) < 1 # straw hat
        lean = fx + (fy - v) * 0.3
        break [45, 55, 85] if (u - lean).abs < 0.012 && v > fy - 0.065
      end)
      next hit if hit
      ground = 0.66 + 0.02 * Math.sin(u * 6)
      if v > ground
        next mix([165, 145, 95], [130, 105, 70], (v - 0.85) * 5) if v > 0.84
        next Math.sin(u * 160 + v * 30) > 0.6 ? [140, 145, 95] : [185, 180, 125]
      end
      # faint outline of Fuji on the left
      fd = (u - 0.25).abs
      fslope = 0.40 + fd * 0.55
      if fd < 0.25 && v > fslope - 0.012
        next v < fslope + 0.012 ? [120, 125, 130] : [238, 236, 225]
      end
      mix([175, 195, 205], [235, 230, 205], smooth(0.0, 0.65, v))
    end

    # Hokusai, Kajikazawa in Kai Province
    piece :kajikazawa, "Kajikazawa in Kai Province", "Katsushika Hokusai", "c. 1831", aspect: 1.45 do |u, v|
      x = u * 1.45
      # fishing lines from the angler's hands into the surf
      lines = [[0.74, 0.33, 1.00, 0.62], [0.74, 0.33, 1.10, 0.56], [0.74, 0.33, 1.18, 0.66]]
      next [20, 20, 30] if lines.any? { |ax, ay, bx, by| JP_SEG.(x, v, ax, ay, bx, by) < 0.005 }
      # the fisherman and the boy on the rock tip
      next [25, 30, 45] if ellipse(u, v, 0.49, 0.36, 0.022, 0.07) < 1
      next [205, 170, 95] if ellipse(u, v, 0.49, 0.285, 0.04, 0.02) < 1
      next [60, 75, 110] if ellipse(u, v, 0.43, 0.40, 0.014, 0.04) < 1
      rock = [[0.0, 0.62], [0.15, 0.55], [0.30, 0.48], [0.45, 0.43], [0.56, 0.42], [0.55, 0.50], [0.45, 0.62], [0.36, 0.78], [0.30, 1.0], [0.0, 1.0]]
      if inside?(u, v, rock)
        next [70, 105, 150] if Math.sin((u * 1.2 - v) * 40) > 0.8
        next mix([28, 45, 80], [10, 18, 40], (v - 0.45) * 2)
      end
      sea_top = 0.50
      if v > sea_top
        # claws of surf around the rock and along the bottom
        foam = Math.sin(u * 40 + Math.sin(v * 25) * 3) * 0.5 + 0.5
        near = Math.exp(-((u - (0.55 - (v - 0.5) * 0.6))**2) * 300)
        next [245, 248, 250] if foam * near > 0.5 || (v > 0.82 && Math.sin(u * 55 + v * 40) > 0.75)
        next mix([95, 150, 205], [40, 90, 165], (v - sea_top) * 2.5)
      end
      # pale Fuji above the mist
      fd = (u - 0.70).abs
      if v > 0.12 + fd * 0.75 && v < 0.40
        next v < 0.17 + 0.02 * Math.sin(u * 80) ? [250, 250, 248] : [140, 165, 195]
      end
      next [245, 240, 225] if v > 0.33 # mist
      mix([90, 120, 170], [235, 232, 215], smooth(0.0, 0.3, v))
    end

    # Hokusai, Kirifuri Waterfall at Kurokami Mountain
    piece :kirifuri_waterfall, "Kirifuri Waterfall at Kurokami Mountain", "Katsushika Hokusai", "c. 1832", aspect: 0.68 do |u, v|
      # tiny travelers at the bottom left
      hit = JP_HIT.([[0.08, 0.86], [0.14, 0.87], [0.20, 0.88]].each do |fx, fy|
        break [200, 160, 90] if ellipse(u, v, fx, fy - 0.035, 0.022, 0.009) < 1
        break [40, 50, 80] if ellipse(u, v, fx, fy, 0.012, 0.03) < 1
      end)
      next hit if hit
      next mix([120, 115, 90], [90, 85, 70], v) if v > 0.89 && u < 0.32 # ledge
      # the falls: one stream at the top splitting into fingers
      cx = 0.52 + 0.03 * Math.sin(v * 5)
      half = v < 0.12 ? 0.07 : 0.07 + (v - 0.12) * 0.25
      if (u - cx).abs < half && v < 0.92
        f = (u - cx) / half
        fingers = v < 0.2 ? 1.0 : Math.cos(f * Math::PI * 2.5 + v * 2)
        if fingers > -0.35
          streak = Math.sin(u * 160 + Math.sin(v * 12) * 2) > 0.3
          next streak ? [235, 245, 250] : mix([60, 120, 190], [30, 80, 160], v)
        end
      end
      # spray and pool
      if v > 0.86
        next [240, 245, 250] if vnoise(u, v, 22) > 0.55
        next [70, 120, 180]
      end
      # dark rocks and cliffs
      if v > 0.07 + 0.04 * Math.sin(u * 9)
        tone = vnoise(u, v, 10)
        base = tone > 0.5 ? [40, 75, 70] : [70, 60, 45]
        next Math.sin(u * 50 + v * 30 + tone * 6) > 0.6 ? Color.scale(base, 0.6) : base
      end
      # trees on top and sky
      next [40, 80, 50] if vnoise(u, v, 30) > 0.55
      [215, 210, 185]
    end

    # Hiroshige, Sudden Shower over Shin-Ohashi Bridge and Atake
    piece :sudden_shower_atake, "Sudden Shower over Shin-Ōhashi Bridge and Atake", "Utagawa Hiroshige", "1857", aspect: 0.68 do |u, v|
      deck = 0.84 - u * 0.30
      col =
        if v < 0.14
          mix([20, 20, 25], [90, 95, 95], smooth(0.0, 0.14, v) * (0.6 + 0.4 * vnoise(u, v, 12)))
        elsif v > 0.34 && v < 0.41 + 0.01 * Math.sin(u * 30)
          Math.sin(u * 60) > 0.3 ? [70, 95, 70] : [45, 70, 55] # far shore of Atake
        elsif ellipse(u, v, 0.30, 0.47, 0.14, 0.012) < 1
          [110, 90, 60] # a raft
        elsif v >= 0.38
          mix([120, 150, 160], [60, 95, 125], (v - 0.4) * 1.5)
        else
          mix([150, 155, 150], [190, 190, 180], (v - 0.14) * 3)
        end
      if v > deck - 0.03 && v < deck + 0.03
        col = v < deck ? [185, 150, 95] : [120, 90, 55] # planks and their shadowed edge
      elsif v > deck && v < 1.0 && ((u * 6 + 0.3) % 1.0) < 0.14
        col = [80, 60, 40] # pilings
      end
      # people hurrying across under umbrellas and straw capes
      cell = (u * 7).floor
      fu = (u * 7) % 1.0
      pv = deck - 0.03
      if noise(cell, 3) > 0.25 && fu > 0.25 && fu < 0.75 && v < pv && v > pv - 0.10
        if v < pv - 0.065
          col = noise(cell, 5) > 0.5 ? [45, 50, 60] : [200, 175, 115] if ellipse(fu, v, 0.5, pv - 0.065, 0.35, 0.035) < 1 && v < pv - 0.065
        else
          col = noise(cell, 6) > 0.5 ? [55, 65, 95] : [150, 120, 70] if (fu - 0.5).abs < 0.18
        end
      end
      rain = ((u * 28 + v * 4) % 1.0) < 0.2 && noise((u * 28 + v * 4).floor, (v * 6).floor) > 0.25
      rain ||= ((u * 19 - v * 2) % 1.0) < 0.14 && noise((u * 19 - v * 2).floor + 40, (v * 5).floor) > 0.4
      rain ? mix(col, [45, 50, 60], 0.4) : col
    end

    # Hiroshige, Plum Park in Kameido
    piece :plum_garden_kameido, "Plum Park in Kameido", "Utagawa Hiroshige", "1857", aspect: 0.68 do |u, v|
      x = u * 0.68
      # blossoms along the branches
      blossoms = [[0.12, 0.30], [0.20, 0.22], [0.30, 0.26], [0.40, 0.20], [0.50, 0.30], [0.58, 0.24], [0.64, 0.32],
                  [0.08, 0.45], [0.16, 0.12], [0.36, 0.36], [0.46, 0.14], [0.26, 0.42], [0.55, 0.40]]
      hit = JP_HIT.(blossoms.each do |bx, by|
        dd = Math.hypot(x - bx, v - by)
        break [210, 60, 70] if dd < 0.008
        break [252, 250, 245] if dd < 0.026
      end)
      next hit if hit
      # the huge foreground branch: trunk rising on the left, limb sweeping right
      trunk = 0.17 + (v - 0.95) * -0.08 + 0.02 * Math.sin(v * 20)
      if v > 0.30 && (x - trunk).abs < 0.075 + 0.02 * Math.sin(v * 13)
        next Math.sin(v * 60 + u * 20) > 0.4 ? [55, 35, 30] : [30, 20, 20]
      end
      limb_v = 0.30 - (x - 0.17) * 0.18 + 0.03 * Math.sin(x * 25)
      next [35, 22, 20] if x > 0.12 && (v - limb_v).abs < 0.045 - (x - 0.17) * 0.05
      twigs = [[0.30, 0.27, 0.42, 0.13], [0.45, 0.25, 0.62, 0.35], [0.20, 0.40, 0.06, 0.48], [0.18, 0.30, 0.14, 0.10]]
      next [35, 22, 20] if twigs.any? { |ax, ay, bx, by| JP_SEG.(x, v, ax, ay, bx, by) < 0.008 }
      # background trees and visitors
      if v > 0.62
        next [60, 40, 35] if ((u * 6) % 1.0) < 0.06 && v < 0.75
        next [60, 60, 80] if v > 0.70 && v < 0.75 && noise((u * 40).floor, 2) > 0.8
        next mix([150, 185, 110], [90, 140, 80], (v - 0.62) * 3)
      end
      if v > 0.52 && vnoise(u, v, 18) > 0.5
        next noise((u * 40).floor, (v * 40).floor) > 0.8 ? [250, 245, 240] : [110, 80, 70]
      end
      ramp(smooth(0.0, 0.55, v), [175, 30, 40], [225, 110, 90], [250, 240, 225], [250, 248, 240])
    end

    # Hiroshige, Fireworks at Ryogoku
    piece :fireworks_ryogoku, "Fireworks at Ryōgoku", "Utagawa Hiroshige", "1858", aspect: 0.68 do |u, v|
      x = u * 0.68
      # burst of sparks
      dx = x - 0.40
      dy = v - 0.30
      r = Math.hypot(dx, dy)
      a = Math.atan2(dy, dx)
      if r < 0.16
        ray = Math.cos(a * 11 + r * 8)
        spark = noise((a * 18).floor, (r * 70).floor)
        next [255, 245, 200] if r < 0.012
        next mix([255, 230, 150], [230, 150, 70], r / 0.16) if ray > 0.85 && spark > 0.3
        next [240, 200, 120] if spark > 0.93
      end
      # trailing rocket
      next [220, 180, 110] if (x - 0.42).abs < 0.006 && v > 0.47 && v < 0.62 && noise(0, (v * 50).floor) > 0.35
      # the bridge across the lower part
      deck = 0.70 + (u - 0.5) * 0.05
      if v > deck - 0.02 && v < deck + 0.015
        next noise((u * 60).floor, 1) > 0.6 && v < deck - 0.005 ? [30, 30, 45] : [20, 20, 30]
      end
      next [18, 18, 28] if v > deck && v < 0.88 && ((u * 10) % 1.0) < 0.1
      if v > 0.62
        # boats on the river
        hit = JP_HIT.([[0.18, 0.92], [0.55, 0.90], [0.82, 0.95], [0.38, 0.97]].each do |px, py|
          break [25, 25, 30] if ellipse(u, v, px, py, 0.09, 0.015) < 1
          break [210, 160, 80] if ellipse(u, v, px, py - 0.025, 0.035, 0.012) < 1
        end)
        next hit if hit
        next Math.sin(v * 120 + u * 6) > 0.8 ? [50, 70, 110] : mix([25, 40, 80], [15, 25, 55], (v - 0.62) * 2)
      end
      # far shore
      next [15, 20, 35] if v > 0.60 - 0.01 * Math.sin(u * 20)
      mix([10, 15, 45], [40, 55, 105], smooth(0.0, 0.65, v))
    end

    # Hiroshige, Night Snow at Kambara
    piece :evening_snow_kanbara, "Night Snow at Kambara", "Utagawa Hiroshige", "1833", aspect: 1.5 do |u, v|
      snow = [238, 238, 240]
      col =
        if v >= 0.80
          # the snowy road with three hunched walkers
          walk = [[0.32, 0.88], [0.44, 0.89], [0.60, 0.87]].find { |fx, fy| ellipse(u, v, fx, fy, 0.022, 0.07) < 1 }
          if walk
            v < walk[1] - 0.035 ? [175, 165, 130] : [55, 55, 70]
          else
            mix(snow, [205, 205, 215], (v - 0.8) * 4)
          end
        elsif v > 0.58
          # village: snow-laden roofs over dark walls
          cell = (u * 7).floor
          fu = (u * 7) % 1.0
          roof = 0.60 + noise(cell, 2) * 0.05
          if fu > 0.08 && fu < 0.92 && v > roof
            if v < roof + 0.05 + 0.02 * (1 - (fu - 0.5).abs * 2)
              snow
            elsif v < 0.76
              noise(cell, 4) > 0.6 && fu > 0.4 && fu < 0.6 && v > 0.68 ? [150, 120, 70] : [50, 48, 52]
            else
              snow
            end
          else
            snow
          end
        elsif v > 0.10 + u * 0.55 + 0.03 * Math.sin(u * 17)
          # the steep snowy hillside, dotted with dark trees
          tree = vnoise(u, v, 10) > 0.66 && Math.sin(u * 120) > 0.3
          tree ? [60, 60, 65] : snow
        elsif u > 0.5 && v > 0.30 + 0.06 * Math.sin(u * 9)
          [70, 70, 76] # far dark hills
        else
          mix([25, 25, 30], [110, 110, 115], smooth(0.0, 0.6, v))
        end
      noise((u * 60).floor, (v * 40).floor) > 0.965 ? [250, 250, 250] : col
    end

    # Hiroshige, Moon Pine, Ueno
    piece :moon_pine_ueno, "Moon Pine, Ueno", "Utagawa Hiroshige", "1857", aspect: 0.68 do |u, v|
      x = u * 0.68
      # the pine branch twisted into a ring
      cx = 0.34
      cy = 0.42
      r = Math.hypot(x - cx, v - cy)
      if (r - 0.20).abs < 0.022 + 0.006 * Math.sin(Math.atan2(v - cy, x - cx) * 5)
        next Math.sin(r * 300) > 0 ? [80, 55, 35] : [55, 35, 25]
      end
      # the trunk coming in from the top left, with needle clumps
      next [60, 40, 28] if JP_SEG.(x, v, 0.0, 0.08, 0.20, 0.25) < 0.025
      clumps = [[0.08, 0.06], [0.22, 0.10], [0.50, 0.20], [0.56, 0.36], [0.05, 0.22], [0.40, 0.60]]
      if clumps.any? { |nx, ny| ellipse(x, v, nx, ny, 0.08, 0.04) < 1 }
        next Math.sin(x * 200 + v * 80) > 0 ? [40, 90, 50] : [25, 60, 40]
      end
      # foreground bank
      next mix([130, 110, 70], [90, 75, 50], (v - 0.8) * 4) if v > 0.80 + 0.02 * Math.sin(u * 10)
      # pond and far shore with town
      if v > 0.58
        next [45, 80, 55] if v < 0.62 && noise((u * 30).floor, 7) > 0.3
        next Math.sin(v * 150) > 0.7 ? [150, 180, 205] : [80, 130, 175]
      end
      if v > 0.53
        next noise((u * 40).floor, 3) > 0.5 ? [80, 70, 65] : [40, 70, 55]
      end
      ramp(v / 0.53, [70, 120, 185], [165, 195, 220], [240, 220, 200], [225, 110, 80])
    end

    # Sharaku, Otani Oniji III as Yakko Edobei
    piece :otani_oniji, "Ōtani Oniji III as Yakko Edobei", "Tōshūsai Sharaku", "1794", aspect: 0.68 do |u, v|
      x = u * 0.68
      skin = [242, 232, 220]
      ink = [20, 18, 22]
      # hands with claw-like fingers
      hands = [[0.13, 0.74, 1], [0.54, 0.70, -1]]
      claw = hands.any? do |hx, hy, dir|
        Math.hypot(x - hx, v - hy) < 0.045 ||
          5.times.any? do |k|
            a = -2.7 + k * 0.38
            JP_SEG.(x, v, hx, hy, hx + Math.cos(a) * 0.10 * dir, hy + Math.sin(a) * 0.10) < 0.014
          end
      end
      next skin if claw
      # face
      fx = 0.34
      fy = 0.32
      face = ellipse(x, v, fx, fy, 0.13, 0.15)
      if face < 1 && v > 0.22
        dx = x - fx
        next ink if (v - (0.29 - dx.abs * 0.35)).abs < 0.012 && dx.abs > 0.025 && dx.abs < 0.10 # brows
        next ink if (v - 0.325).abs < 0.008 && (dx.abs - 0.055).abs < 0.022 # eyes
        next [180, 120, 110] if dx.abs < 0.012 && v > 0.33 && v < 0.39 # nose
        next [150, 30, 40] if (v - (0.41 + dx.abs * 0.25)).abs < 0.01 && dx.abs < 0.06 # grimace
        next mix(skin, [215, 195, 185], face)
      end
      # hair: shaved blue-grey pate, black sides and topknot
      next [120, 130, 150] if ellipse(x, v, fx, 0.20, 0.09, 0.07) < 1
      next ink if ellipse(x, v, fx, 0.24, 0.16, 0.12) < 1 || ellipse(x, v, fx, 0.11, 0.035, 0.03) < 1
      # dark kimono with white under-collar
      shoulder = 0.48 + (x - fx).abs * 0.35
      if v > shoulder - 0.02 && (x - fx).abs < 0.30
        cdx = (x - fx).abs
        next [235, 235, 230] if v > 0.45 && (cdx - (v - 0.45) * 0.5).abs < 0.014
        next skin if v > 0.45 && cdx < (v - 0.45) * 0.5 && v < 0.58
        next Math.sin(x * 90 + v * 30) > 0.85 ? [60, 55, 70] : [25, 25, 35]
      end
      # dark glittering mica ground
      noise((u * 50).floor, (v * 70).floor) > 0.9 ? [120, 115, 125] : [55, 50, 58]
    end

    # Utamaro, Three Beauties of the Present Day
    piece :three_beauties, "Three Beauties of the Present Day", "Kitagawa Utamaro", "c. 1793", aspect: 0.68 do |u, v|
      x = u * 0.68
      skin = [248, 240, 230]
      hair = [20, 18, 22]
      # [face x, face y, kimono color]; the top beauty sits behind the other two
      beauties = [[0.17, 0.58, [70, 60, 80]], [0.51, 0.58, [200, 110, 60]], [0.34, 0.30, [40, 40, 45]]]
      hit = JP_HIT.(beauties.each do |fx, fy, kc|
        e = ellipse(x, v, fx, fy, 0.075, 0.095)
        if e < 1
          dx = x - fx
          break hair if (v - (fy - 0.015)).abs < 0.006 && (dx.abs - 0.03).abs < 0.015
          break [190, 40, 50] if (v - (fy + 0.055)).abs < 0.007 && dx.abs < 0.012
          break skin
        end
        break hair if ellipse(x, v, fx, fy - 0.10, 0.10, 0.07) < 1 || ellipse(x, v, fx, fy - 0.03, 0.10, 0.05) < 1
        break [220, 190, 110] if (v - (fy - 0.13)).abs < 0.008 && (x - fx).abs < 0.12 # comb
        if v > fy + 0.09 && (x - fx).abs < 0.06 + (v - fy - 0.09) * 0.9
          break [245, 240, 235] if ((x - fx).abs - (v - fy - 0.09) * 0.4).abs < 0.012 # collar
          break skin if (x - fx).abs < (v - fy - 0.09) * 0.4 && v < fy + 0.16
          break Math.sin(x * 120 + v * 60) > 0.7 ? Color.scale(kc, 1.3) : kc
        end
      end)
      next hit if hit
      jitter([225, 185, 95], u, v, 10, 20)
    end

    # Sotatsu, Wind God and Thunder God
    piece :fujin_raijin, "Wind God and Thunder God", "Tawaraya Sōtatsu", "17th century", aspect: 2.2 do |u, v|
      x = u * 2.2
      dark = [35, 30, 30]
      # [center x, skin, facing]: Fujin crouching on the left, Raijin on the right
      gods = [[0.40, [80, 155, 105], 1], [1.80, [240, 238, 228], -1]]
      hit = JP_HIT.(gods.each do |cx, skin, dir|
        next if (x - cx).abs > 0.45
        hx = cx + 0.05 * dir
        if dir.positive?
          # the long white wind bag, looped over his head from hand to hand
          r = Math.hypot(x - cx, (v - 0.40) * 1.1)
          break(Math.sin(r * 90) > 0.6 ? [190, 195, 185] : [240, 240, 232]) if (r - 0.25).abs < 0.04 && v < 0.44
        else
          # the ring of drums around the thunder god
          r = Math.hypot(x - cx, v - 0.38)
          ang = Math.atan2(v - 0.38, x - cx)
          bead = (ang / (Math::PI / 4)).round * (Math::PI / 4)
          bd = Math.hypot(x - (cx + Math.cos(bead) * 0.28), v - (0.38 + Math.sin(bead) * 0.28))
          break dark if bd < 0.055 && bd > 0.04
          break [200, 80, 45] if bd < 0.04
          break dark if (r - 0.28).abs < 0.008 && v < 0.6
        end
        # wild hair: dark strokes flaring from the head
        hair = 5.times.any? do |k|
          a = -2.6 + k * 0.4
          JP_SEG.(x, v, hx, 0.24, hx + Math.cos(a) * 0.12, 0.24 + Math.sin(a) * 0.12) < 0.016
        end
        break dark if hair
        # head, crouched body and bent limbs, outlined in ink
        head = ellipse(x, v, hx, 0.28, 0.065, 0.065)
        body = ellipse(x, v, cx, 0.45, 0.10, 0.12)
        limbs = [[cx - 0.06, 0.38, cx - 0.22, 0.40], [cx + 0.06, 0.38, cx + 0.22, 0.40],
                 [cx - 0.05, 0.52, cx - 0.16, 0.48], [cx - 0.16, 0.48, cx - 0.14, 0.62],
                 [cx + 0.05, 0.52, cx + 0.16, 0.50], [cx + 0.16, 0.50, cx + 0.18, 0.62]]
        ld = limbs.map { |ax, ay, bx, by| JP_SEG.(x, v, ax, ay, bx, by) }.min
        if head < 1
          break dark if (v - 0.27).abs < 0.01 && ((x - hx) * dir - 0.025).abs < 0.012 # glaring eye
          break [180, 40, 35] if (v - 0.31).abs < 0.008 && ((x - hx) * dir - 0.02).abs < 0.025 # open mouth
          break head > 0.6 ? Color.scale(skin, 0.75) : skin
        end
        break(body > 0.65 ? Color.scale(skin, 0.75) : skin) if body < 1
        break [160, 45, 35] if ellipse(x, v, cx, 0.55, 0.12, 0.035) < 1 # loincloth
        break(ld > 0.022 ? Color.scale(skin, 0.6) : skin) if ld < 0.03
        # the dark swirling cloud beneath
        cr = ellipse(x, v, cx, 0.68, 0.36, 0.13) - (vnoise(u, v, 12) - 0.5) * 0.9
        if cr < 1
          sw = Math.sin(Math.hypot(x - cx, (v - 0.68) * 2.5) * 45 - Math.atan2(v - 0.68, x - cx) * 2)
          break sw > 0.6 ? [130, 130, 135] : [55, 55, 60]
        end
      end)
      next hit if hit
      # gold leaf with faint square seams
      gold = jitter([215, 170, 70], u, v, 10, 12)
      ((x * 6) % 1.0) < 0.04 || ((v * 4) % 1.0) < 0.04 ? Color.scale(gold, 0.92) : gold
    end

    # Hasegawa Tohaku, Pine Trees
    piece :pine_trees_tohaku, "Pine Trees", "Hasegawa Tōhaku", "c. 1595", aspect: 2.5 do |u, v|
      paper = jitter([238, 234, 222], u, v, 4, 10)
      # mist: bottom and middle fade to paper, with drifting soft banks
      mist = (1.0 - smooth(0.40, 0.95, v) * 0.97) * (0.7 + 0.3 * smooth(0.3, 0.7, vnoise(u * 0.7, v, 4)))
      next paper if mist < 0.02
      ink = 0.0
      JP_PINES.each do |tx, top, dens, lean, blots|
        next if v < top - 0.08 || (u - tx).abs > 0.16
        cx = tx + (v - top) * lean
        a = (u - cx).abs < 0.006 && v > top ? 0.7 : 0.0 # thin trunk
        blots.each do |dy, dx, rx|
          e = ellipse(u, v, cx + dx * 1.3, top + dy, rx * 1.6, 0.055) + (vnoise(u, v, 22) - 0.5) * 0.6
          next unless e < 1
          a = [a, (1 - e) * 2.2 * (0.45 + 0.55 * vnoise(u * 2, v, 50))].max
        end
        ink = [ink, a.clamp(0.0, 1.0) * dens].max
      end
      mix(paper, [28, 28, 28], ink * mist)
    end

    # Ogata Korin, Irises
    piece :irises_korin, "Irises", "Ogata Kōrin", "c. 1705", aspect: 2.4 do |u, v|
      x = u * 2.4
      clumps = [[0.10, 0.20], [0.35, 0.32], [0.62, 0.15], [0.90, 0.40], [1.15, 0.22], [1.42, 0.30], [1.70, 0.12], [1.98, 0.35], [2.25, 0.20]]
      hit = JP_HIT.(clumps.each_with_index do |(cx, top), i|
        dx = x - cx
        next if dx.abs > 0.14
        # blossoms at the top of the clump
        petal = 5.times.map do |k|
          ellipse(x, v, cx + (k - 2) * 0.045 + (noise(i, k) - 0.5) * 0.03, top + 0.06 + noise(k, i) * 0.12, 0.03, 0.07)
        end.min
        break(petal < 0.35 ? [120, 110, 210] : [45, 40, 140]) if petal < 1
        # sword leaves
        base = top + 0.15
        if v > base && dx.abs < 0.09 + (1 - v) * 0.02
          blade = Math.sin(dx * 110 + (v - base) * 6 * (dx < 0 ? 1 : -1))
          break(blade > 0.6 ? [70, 140, 60] : [35, 100, 45]) if blade > -0.1
        end
      end)
      next hit if hit
      jitter([220, 175, 70], u, v, 10, 14)
    end

    # Ogata Korin, Red and White Plum Blossoms
    piece :red_white_plum, "Red and White Plum Blossoms", "Ogata Kōrin", "c. 1710s", aspect: 2.2 do |u, v|
      x = u * 2.2
      # the stylized stream, widening downward
      sc = 1.1 + 0.08 * Math.sin(v * 4)
      half = 0.08 + v * v * 0.45
      if (x - sc).abs < half
        swirl = Math.sin((x - sc) * 30 + Math.sin(v * 14 + x * 6) * 3 + v * 10)
        next swirl > 0.75 ? [150, 150, 155] : [35, 35, 45]
      end
      # white plum on the left: trunk from the left edge, branch dipping and rising
      white = [[0.30, 0.15], [0.42, 0.11], [0.18, 0.32], [0.40, 0.58], [0.48, 0.62], [0.12, 0.70], [0.24, 0.46]]
      next [252, 252, 248] if white.any? { |bx, by| Math.hypot(x - bx, v - by) < 0.035 }
      wb = JP_SEG.(x, v, 0.0, 0.85, 0.25, 0.55) < 0.04 || JP_SEG.(x, v, 0.25, 0.55, 0.20, 0.25) < 0.025 ||
           JP_SEG.(x, v, 0.20, 0.25, 0.45, 0.10) < 0.018 || JP_SEG.(x, v, 0.25, 0.55, 0.50, 0.60) < 0.018
      next [50, 55, 40] if wb
      # red plum on the right: a thick trunk leaning in from the right
      red = [[1.70, 0.12], [1.62, 0.40], [1.78, 0.18], [1.70, 0.43], [2.05, 0.20], [1.98, 0.40], [1.90, 0.10]]
      next [215, 50, 60] if red.any? { |bx, by| Math.hypot(x - bx, v - by) < 0.035 }
      rb = JP_SEG.(x, v, 2.05, 1.0, 1.85, 0.55) < 0.07 || JP_SEG.(x, v, 1.85, 0.55, 1.95, 0.25) < 0.05 ||
           JP_SEG.(x, v, 1.95, 0.25, 1.65, 0.12) < 0.025 || JP_SEG.(x, v, 1.88, 0.45, 1.60, 0.40) < 0.02
      next Math.sin(v * 50) > 0.6 ? [70, 80, 50] : [45, 45, 35] if rb
      next [90, 130, 70] if v > 0.9 && (x < 0.6 || x > 1.6) # grassy bank
      jitter([220, 180, 80], u, v, 10, 12)
    end

    # Toba Sojo (attr.), Choju-giga
    piece :choju_giga, "Chōjū-giga (Frolicking Animals)", "attributed to Toba Sōjō", "12th century", aspect: 2.5 do |u, v|
      x = u * 2.5
      ink = [40, 35, 30]
      line = 0.024
      # [cx, cy, rx, ry, angle, fill]: the rabbit thrown off balance and the frog pushing it
      parts = [
        [0.82, 0.60, 0.15, 0.27, 0.45, [250, 246, 236]],  # rabbit body
        [0.62, 0.32, 0.12, 0.10, 0.30, [250, 246, 236]],  # rabbit head
        [0.50, 0.14, 0.045, 0.15, 0.6, [250, 246, 236]],  # long ears
        [0.62, 0.11, 0.045, 0.15, 0.3, [250, 246, 236]],
        [1.42, 0.62, 0.24, 0.20, 0.0, [205, 200, 175]],   # frog body
        [1.22, 0.40, 0.06, 0.06, 0.0, [205, 200, 175]],   # frog eyes
        [1.40, 0.38, 0.06, 0.06, 0.0, [205, 200, 175]],
        [1.70, 0.86, 0.12, 0.05, 0.4, [205, 200, 175]],   # frog legs
        [1.18, 0.88, 0.12, 0.05, -0.4, [205, 200, 175]]
      ]
      dists = parts.map { |cx, cy, rx, ry, ang| JP_RING.(x, v, cx, cy, rx, ry, ang) }
      next ink if dists.any? { |dd| dd.abs < line }
      next ink if Math.hypot(x - 0.58, v - 0.30) < 0.024 || Math.hypot(x - 1.22, v - 0.40) < 0.025 || Math.hypot(x - 1.40, v - 0.38) < 0.025
      # arms locked in the struggle, and the frog's wide mouth
      next ink if JP_SEG.(x, v, 0.95, 0.42, 1.22, 0.55) < 0.02 || JP_SEG.(x, v, 1.20, 0.65, 0.95, 0.66) < 0.02
      next ink if JP_SEG.(x, v, 1.20, 0.52, 1.42, 0.50) < 0.015
      idx = dists.index(&:negative?)
      next parts[idx][5] if idx
      # grass tufts
      tufts = [[0.25, 0.95], [1.95, 0.94], [2.30, 0.92], [0.05, 0.93]]
      next ink if tufts.any? { |gx, gy| 3.times.any? { |k| JP_SEG.(x, v, gx, gy, gx + (k - 1) * 0.07, gy - 0.16 - k * 0.03) < 0.014 } }
      jitter([238, 226, 196], u, v, 6, 10)
    end

    # Hishikawa Moronobu, Beauty Looking Back
    piece :mikaeri_bijin, "Beauty Looking Back", "Hishikawa Moronobu", "late 17th century", aspect: 0.5 do |u, v|
      # head turned back over the shoulder
      next [245, 232, 215] if ellipse(u, v, 0.60, 0.15, 0.06, 0.035) < 1
      next [20, 18, 20] if ellipse(u, v, 0.48, 0.13, 0.11, 0.04) < 1 || ellipse(u, v, 0.43, 0.17, 0.05, 0.05) < 1
      next [200, 160, 60] if (v - 0.10).abs < 0.006 && (u - 0.50).abs < 0.06 # comb
      body = [[0.40, 0.20], [0.62, 0.19], [0.70, 0.32], [0.66, 0.50], [0.60, 0.70], [0.66, 0.88], [0.62, 0.95],
              [0.22, 0.97], [0.16, 0.93], [0.34, 0.80], [0.40, 0.55], [0.36, 0.35]]
      if inside?(u, v, body)
        # obi
        next(Math.sin(u * 60) > 0.5 ? [90, 110, 90] : [50, 70, 60]) if v > 0.38 && v < 0.45
        # roundels of flowers on the red kimono
        cu = (u * 7).floor
        cv = (v * 10).floor
        rx = (u * 7) % 1.0 - 0.5
        ry = (v * 10) % 1.0 - 0.5
        if Math.hypot(rx * 1.4, ry) < 0.28 && (cu + cv).even?
          next noise(cu, cv) > 0.5 ? [240, 220, 150] : [120, 160, 120]
        end
        next mix([200, 45, 40], [160, 30, 35], v)
      end
      # a hand peeking from the sleeve
      next [245, 232, 215] if ellipse(u, v, 0.68, 0.42, 0.03, 0.02) < 1
      jitter([232, 220, 190], u, v, 6, 10)
    end

    # Zhang Zeduan, Along the River During the Qingming Festival
    piece :qingming_scroll, "Along the River During the Qingming Festival", "Zhang Zeduan", "12th century", aspect: 2.5 do |u, v|
      x = u * 2.5
      silk = jitter([210, 185, 140], u, v, 8, 14)
      # the rainbow bridge arching over the river
      bc = 1.25
      bw = 0.50
      if (x - bc).abs < bw
        t = (x - bc) / bw
        top = 0.40 - 0.22 * (1 - t * t)
        if v > top - 0.08 && v < top
          next noise((x * 50).floor, (v * 40).floor) > 0.4 ? [70, 50, 40] : [180, 90, 60] if noise((x * 50).floor + 7, (v * 40).floor) > 0.35 # crowd
          next silk
        end
        next [95, 65, 40] if v >= top && v < top + 0.06
        next [80, 55, 35] if v >= top + 0.06 && v < top + 0.14 && Math.sin((x - bc) * 60 + v * 30).abs < 0.4
      end
      # river running across, slightly falling to the right
      r1 = 0.44 + u * 0.10
      r2 = 0.80 + u * 0.06
      if v > r1 && v < r2
        # boats with cabins, one lowering its mast under the bridge
        hit = JP_HIT.([[0.45, 0.66, 0.24], [2.05, 0.74, 0.24], [1.62, 0.62, 0.10]].each do |bx, by, bl|
          break [90, 60, 40] if ellipse(x, v, bx, by, bl, 0.05) < 1
          break [150, 110, 70] if ellipse(x, v, bx, by - 0.07, bl * 0.6, 0.045) < 1
        end)
        next hit if hit
        next [70, 50, 35] if JP_SEG.(x, v, 0.50, 0.60, 0.72, 0.18) < 0.014 # mast
        next Math.sin(v * 60 + Math.sin(x * 8) * 2) > 0.9 ? [160, 165, 140] : [115, 125, 105]
      end
      # banks lined with tiled roofs and willows
      cell = (x * 4).floor
      cxf = (x * 4) % 1.0
      far = v < r1
      hv = far ? r1 - 0.17 : r2 + 0.04
      if noise(cell, far ? 1 : 3) > 0.3 && cxf > 0.15 && cxf < 0.75 && v > hv && (v < r1 || !far)
        next [80, 75, 70] if v < hv + 0.06
        next [190, 165, 120] if v < hv + 0.15
      end
      if ellipse(cxf, v, 0.92, far ? hv - 0.02 : hv + 0.06, 0.28, 0.14) < 1 && noise(cell, far ? 2 : 4) > 0.35
        next vnoise(u, v, 40) > 0.5 ? [100, 115, 70] : [70, 85, 55] # willows
      end
      next [60, 45, 35] if noise((x * 50).floor, (v * 30).floor) > 0.94 && v > 0.2 # people
      silk
    end

    # Fan Kuan, Travelers among Mountains and Streams
    piece :travelers_mountains_streams, "Travelers among Mountains and Streams", "Fan Kuan", "c. 1000", aspect: 0.5 do |u, v|
      silk = jitter([180, 155, 115], u, v, 8, 12)
      # the monumental central peak, filling the top
      peak = [[0.03, 0.70], [0.05, 0.32], [0.12, 0.15], [0.26, 0.05], [0.50, 0.025], [0.72, 0.05], [0.87, 0.14],
              [0.95, 0.32], [0.97, 0.70]]
      if inside?(u, v, peak)
        next [230, 220, 195] if (u - (0.78 + (v - 0.3) * 0.04)).abs < 0.012 && v > 0.26 && v < 0.56 # waterfall
        next [45, 50, 35] if v < 0.09 + 0.02 * Math.sin(u * 20) && vnoise(u, v, 40) > 0.45 # scrub on the summit
        tex = Math.sin(u * 140 + vnoise(u, v, 10) * 8) * 0.5 + 0.5
        dot = noise((u * 80).floor, (v * 140).floor) > 0.65
        base = mix([100, 80, 55], [45, 35, 25], tex * 0.6 + (dot ? 0.3 : 0) + (0.5 - (u - 0.5).abs) * 0.4)
        next mix(base, [215, 200, 165], smooth(0.48, 0.66, v))
      end
      next mix(silk, [215, 200, 165], 0.6) if v > 0.60 && v < 0.70 # mist band
      if v > 0.66
        # a little caravan of travelers on the path at the lower right
        next [35, 30, 25] if u > 0.62 && u < 0.84 && (v - 0.86).abs < 0.012 && noise((u * 60).floor, 9) > 0.35
        # foreground boulders and groves
        rock = ellipse(u, v, 0.30, 0.95, 0.34, 0.12) < 1 || ellipse(u, v, 0.92, 0.95, 0.20, 0.06) < 1
        next mix([85, 68, 48], [40, 32, 22], vnoise(u, v, 20)) if rock
        grove = ellipse(u, v, 0.78, 0.74, 0.20, 0.07) < 1 || ellipse(u, v, 0.18, 0.76, 0.18, 0.08) < 1
        next(vnoise(u, v, 40) > 0.45 ? [40, 45, 30] : [75, 70, 45]) if grove
        next mix(silk, [150, 125, 90], 0.4)
      end
      mix(silk, [215, 200, 165], 0.4) # pale sky
    end
  end
end
