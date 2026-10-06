# frozen_string_literal: true

module Dopairb
  module Gallery
    # Renaissance and Golden Age painters (helpers and painters use an rn_ prefix).
    module Paint
      module_function

      # Distance from (u, v) to the segment (x1, y1)-(x2, y2); sx scales the u axis.
      def rn_seg(u, v, x1, y1, x2, y2, sx = 1.0)
        dx = (x2 - x1) * sx
        dy = y2 - y1
        px = (u - x1) * sx
        py = v - y1
        t = ((px * dx + py * dy) / (dx * dx + dy * dy + 1e-12)).clamp(0.0, 1.0)
        Math.hypot(px - dx * t, py - dy * t)
      end

      # A simple standing (or seated) figure: :head, :body or nil.
      # x: center u, top: v of the top of the head, h: height and w: width in v units,
      # sx: the picture's aspect so heads stay round.
      def rn_fig(u, v, x, top, h, w, sx)
        hr = h * 0.08
        return :head if (((u - x) * sx) / (hr * 0.85))**2 + ((v - top - hr) / hr)**2 < 1
        t = (v - top - hr * 1.8) / (h - hr * 1.8)
        return nil if t < 0 || t > 1
        (u - x).abs * sx < w * 0.5 * (0.7 + 0.5 * t) ? :body : nil
      end

      # Botticelli, The Birth of Venus
      def rn_birth_of_venus(u, v)
        a = 1.58
        skin = [238, 214, 190]
        hair = [196, 128, 62]
        # orange trees at the right edge
        edge = 0.91 + 0.015 * Math.sin(v * 11)
        if u > edge
          return [92, 70, 45] if (u - 0.95).abs < 0.008 && v > 0.15
          return noise((u * 70).floor, (v * 50).floor) > 0.9 ? [210, 150, 70] : jitter([45, 72, 50], u, v, 14)
        end
        # the green shore under the attendant
        return jitter([96, 120, 70], u, v, 12) if v > 0.84 - (u - 0.7) * 0.35 && u > 0.68
        # the scallop shell
        su = 0.5
        sv = 0.97
        if ellipse(u, v, su, sv, 0.17, 0.2) < 1 && v < 0.94 && v > 0.78
          ang = Math.atan2(v - sv, (u - su) * a)
          return [170, 130, 85] if ellipse(u, v, su, sv, 0.17, 0.2) > 0.85
          return Math.sin(ang * 26) > 0.3 ? [200, 165, 115] : [240, 220, 178]
        end
        # Venus: long golden-red hair over a pale S-shaped figure
        return mix(hair, [150, 85, 40], 0.2) if ellipse(u, v, 0.5, 0.115, 0.03, 0.055) < 1 && v < 0.11
        return skin if ellipse(u, v, 0.5, 0.135, 0.022, 0.05) < 1
        # the long hair: down her left side and drawn across the hips, a few strands blowing right
        lock = 0.47 - 0.012 * Math.sin(v * 14)
        hair_px = (v > 0.1 && v < 0.6 && (u - lock).abs < 0.016 + (v - 0.1) * 0.03) ||
                  rn_seg(u, v, 0.465, 0.55, 0.505, 0.63, a) < 0.035 ||
                  rn_seg(u, v, 0.52, 0.1, 0.565, 0.24, a) < 0.016 || rn_seg(u, v, 0.53, 0.14, 0.555, 0.32, a) < 0.012
        return Math.sin(v * 70 + u * 40) > 0.5 ? [228, 170, 92] : hair if hair_px
        body = [[0.482, 0.18], [0.52, 0.18], [0.538, 0.3], [0.532, 0.46], [0.522, 0.6], [0.518, 0.8], [0.488, 0.8], [0.48, 0.6], [0.47, 0.46], [0.472, 0.3]]
        return mix(skin, [205, 170, 140], smooth(0.49, 0.54, u)) if inside?(u, v, body)
        # the attendant (Hora) with the pink cloak held out toward Venus
        fig = rn_fig(u, v, 0.77, 0.16, 0.66, 0.11, a)
        return [232, 200, 170] if fig == :head
        cloak = [[0.735, 0.28], [0.65, 0.3], [0.6, 0.42], [0.61, 0.66], [0.64, 0.76], [0.71, 0.64], [0.74, 0.45]]
        if inside?(u, v, cloak)
          return noise((u * 60).floor, (v * 40).floor) > 0.88 ? [180, 60, 60] : jitter([230, 160, 160], u, v, 14)
        end
        if fig == :body
          return noise((u * 70).floor, (v * 50).floor) > 0.85 ? [80, 110, 170] : jitter([236, 232, 214], u, v, 10)
        end
        # the winds flying in from the left
        return [100, 140, 125] if rn_seg(u, v, 0.03, 0.15, 0.27, 0.27, a) < 0.07 # Zephyr's blue-green cloak
        return skin if rn_seg(u, v, 0.05, 0.3, 0.27, 0.33, a) < 0.045 # Aura
        return [232, 205, 180] if dist(u, v, 0.29, 0.27, a) < 0.04
        return [215, 195, 170] if dist(u, v, 0.29, 0.34, a) < 0.035
        return [120, 160, 140] if rn_seg(u, v, 0.08, 0.38, 0.22, 0.42, a) < 0.03 # trailing drapery
        # falling roses
        return [235, 150, 160] if u > 0.18 && u < 0.42 && v < 0.6 && noise((u * 50).floor, (v * 35).floor) > 0.94
        horizon = 0.46
        if v > horizon
          chevron = Math.sin(v * 110 + Math.sin(u * 70).abs * 5)
          sea = mix([150, 185, 170], [110, 150, 140], (v - horizon) / 0.5)
          return chevron > 0.85 ? mix(sea, [240, 245, 235], 0.6) : sea
        end
        jitter(mix([150, 180, 175], [205, 218, 205], v / horizon), u, v, 8)
      end

      # Botticelli, Primavera
      def rn_primavera(u, v)
        a = 1.55
        # the figures, left to right: [u, top, height, width, gown color]
        figs = [
          [0.08, 0.17, 0.74, 0.12, [176, 40, 30]],   # Mercury
          [0.18, 0.18, 0.72, 0.1, [236, 232, 222]],  # the three Graces
          [0.245, 0.17, 0.73, 0.1, [228, 224, 214]],
          [0.31, 0.19, 0.71, 0.1, [236, 230, 218]],
          [0.5, 0.25, 0.64, 0.12, [190, 50, 40]],    # Venus, red mantle
          [0.655, 0.2, 0.7, 0.13, [240, 236, 222]],  # Flora
          [0.775, 0.19, 0.71, 0.1, [222, 222, 210]], # Chloris
          [0.9, 0.08, 0.7, 0.12, [80, 115, 120]] # Zephyr
        ]
        # Cupid hovering above Venus
        return [200, 90, 70] if dist(u, v, 0.5, 0.11, a) < 0.035
        return [230, 200, 170] if dist(u, v, 0.5, 0.07, a) < 0.022
        figs.each_with_index do |(fx, ft, fh, fw, col), i|
          fx2 = fx + (i == 7 ? (v - ft) * -0.12 : 0) # Zephyr leans in
          part = rn_fig(u, v, fx2, ft, fh, fw, a)
          next unless part
          return [234, 208, 180] if part == :head
          if i == 4 # Venus: white gown under the red mantle
            return (u - 0.5).abs < 0.012 && v > 0.36 ? [236, 228, 214] : jitter(col, u, v, 12)
          end
          if i == 5 && noise((u * 70).floor + 7, (v * 50).floor) > 0.72 # Flora's flowered dress
            return [[220, 70, 80], [90, 140, 200], [230, 200, 80]][(noise((u * 90).floor, (v * 60).floor) * 3).floor % 3]
          end
          return mix(col, [150, 140, 125], (u - fx2).abs * a * 6) # sheer gowns, shaded at the edges
        end
        # the flowery meadow
        if v > 0.84
          n = noise((u * 90).floor, (v * 70).floor)
          return [235, 230, 210] if n > 0.9
          return [210, 80, 80] if n > 0.85
          return [90, 120, 190] if n > 0.82
          return jitter([35, 55, 35], u, v, 10)
        end
        # the arch of trees around Venus opening onto pale sky
        ae = ellipse(u, v, 0.5, 0.42, 0.075, 0.36)
        return jitter([165, 175, 160], u, v, 14) if ae < 1 && ae > 0.55
        # the dark orange grove
        return [55, 40, 28] if Math.sin(u * 55) > 0.93 # trunks
        return [228, 140, 50] if v < 0.62 && noise((u * 48).floor, (v * 34).floor) > 0.88 # oranges
        return [135, 150, 140] if v < 0.55 && vnoise(u, v, 14) > 0.74 # sky between the leaves
        jitter([30, 44, 30], u, v, 12, 50)
      end

      # Leonardo da Vinci, The Last Supper
      def rn_last_supper(u, v)
        a = 1.9
        vp_u = 0.5
        vp_v = 0.4
        # the long table
        if v > 0.62 && v < 0.82 && u > 0.03 && u < 0.97
          if v < 0.67
            return [150, 120, 80] if v < 0.645 && noise((u * 70).floor, 3) > 0.8 # bread and plates
            return [238, 235, 225]
          end
          return Math.sin(u * 120) > 0.85 ? [200, 200, 195] : [222, 220, 210] # cloth hanging down
        end
        # thirteen figures behind the table, in groups of three around Jesus
        if v > 0.36 && v < 0.67
          if inside?(u, v, [[0.5, 0.39], [0.565, 0.67], [0.435, 0.67]])
            return [70, 50, 35] if dist(u, v, 0.5, 0.44, a) < 0.04 && v < 0.43
            return [225, 185, 150] if dist(u, v, 0.5, 0.45, a) < 0.04
            return u > 0.5 + (v - 0.45) * 0.1 ? [45, 70, 140] : [180, 40, 35]
          end
          cols = [[90, 120, 80], [180, 120, 60], [70, 90, 140], [160, 60, 50], [120, 110, 100], [200, 160, 90],
                  [80, 110, 150], [150, 70, 60], [110, 130, 90], [180, 100, 70], [90, 90, 120], [170, 150, 110]]
          [0.08, 0.145, 0.205, 0.285, 0.345, 0.405, 0.595, 0.655, 0.72, 0.795, 0.855, 0.92].each_with_index do |fx, i|
            top = 0.4 + noise(i, 1) * 0.06
            lean = (noise(i, 2) - 0.5) * 0.03
            part = rn_fig(u, v, fx + lean * (0.6 - v) * 4, top - 0.02, 0.5, 0.14, a)
            next unless part
            return part == :head ? [215, 170, 130] : cols[i]
          end
        end
        # the room in one-point perspective
        bw_r = 0.64
        bw_t = 0.14
        bw_b = 0.62
        if (u - vp_u).abs < bw_r - vp_u && v > bw_t && v < bw_b
          # three windows on the back wall, the middle one framing Jesus
          [[0.5, 0.045, 0.2], [0.405, 0.022, 0.25], [0.595, 0.022, 0.25]].each do |wx, hw, wt|
            next unless (u - wx).abs < hw && v > wt && v < 0.5
            return v < 0.38 ? mix([215, 228, 230], [180, 200, 205], v * 2) : [120, 140, 110]
          end
          return [150, 130, 100] if (u - 0.5).abs < 0.06 && v > 0.17 && v < 0.2 # pediment
          return jitter([150, 135, 105], u, v, 10)
        end
        s = (u - vp_u).abs / (bw_r - vp_u)
        ceil_v = vp_v + (bw_t - vp_v) * s
        floor_v = vp_v + (bw_b - vp_v) * s
        if v < ceil_v
          # coffered ceiling
          depth = 1.0 / [(vp_v - v) / (vp_v - bw_t), 1.0].max
          across = (u - vp_u) * depth
          return Math.sin(depth * 22) > 0.6 || Math.sin(across * 40) > 0.8 ? [90, 70, 50] : [130, 105, 75]
        end
        if v < floor_v
          # side walls with dark tapestries
          depth = 1.0 / s
          t = (v - ceil_v) / (floor_v - ceil_v)
          panel = [[0.3, 0.42], [0.5, 0.62], [0.7, 0.8], [0.88, 0.96]].any? { |d0, d1| depth.between?(d0, d1) }
          return Math.sin(t * 30) > 0.5 ? [55, 40, 30] : [35, 28, 22] if panel && t > 0.1 && t < 0.75
          return jitter([130, 115, 90], u, v, 10)
        end
        jitter([75, 60, 45], u, v, 10)
      end

      # Leonardo da Vinci, Lady with an Ermine
      def rn_lady_with_ermine(u, v)
        a = 0.74
        skin = [238, 214, 188]
        # her long hand stroking the ermine
        return mix(skin, [195, 160, 130], (u - 0.5) * 4) if rn_seg(u, v, 0.7, 0.8, 0.52, 0.67, a) < 0.03
        # the ermine, white, curled diagonally in her arms with its head to the right
        return [40, 30, 25] if dist(u, v, 0.535, 0.515, a) < 0.011 # eye
        ermine = [[0.3, 0.95], [0.27, 0.82], [0.33, 0.68], [0.41, 0.58], [0.47, 0.51], [0.5, 0.48], [0.535, 0.49], [0.6, 0.52],
                  [0.54, 0.55], [0.51, 0.61], [0.49, 0.72], [0.45, 0.86], [0.41, 0.97]]
        if inside?(u, v, ermine)
          back = rn_seg(u, v, 0.3, 0.9, 0.48, 0.52, a)
          return mix([248, 244, 232], [175, 165, 150], smooth(0.02, 0.07, back) * 0.6 + smooth(0.5, 0.9, v) * 0.3)
        end
        # face, turned three-quarters toward the right
        if ellipse(u, v, 0.565, 0.3, 0.115, 0.105) < 1 && v > 0.215
          return [30, 22, 18] if (v - 0.23).abs < 0.008 # the fine band across the forehead
          return [70, 45, 35] if ((v - 0.29).abs < 0.012) && ((u - 0.58).abs < 0.018 || (u - 0.65).abs < 0.016) # eyes
          return [185, 105, 95] if (v - 0.365).abs < 0.007 && (u - 0.61).abs < 0.022 # lips
          return mix(skin, [205, 170, 140], smooth(0.56, 0.68, u) * 0.6 + smooth(0.48, 0.45, u) * 0.4)
        end
        # smooth dark hair drawn down along the cheeks and under the chin
        return [50, 36, 28] if ellipse(u, v, 0.55, 0.29, 0.14, 0.125) < 1 && v < 0.41
        # neck and the black bead necklace
        if (u - 0.56).abs < 0.06 && v > 0.36 && v < 0.52
          return [30, 25, 22] if (v - (0.47 + (u - 0.56)**2 * 4)).abs < 0.01 && Math.sin(u * 200) > -0.3
          return mix(skin, [205, 170, 140], (v - 0.36) * 4)
        end
        # dress: square neckline, blue mantle on her right shoulder, red sleeve on the left
        shoulders = 0.52 + (u - 0.56).abs * 0.35
        if v > shoulders && u > 0.1
          return mix(skin, [210, 175, 145], 0.3) if (u - 0.56).abs < 0.11 && v < 0.61 && v > 0.52
          return [170, 140, 70] if (u - 0.56).abs < 0.13 && v < 0.64
          return jitter([60, 80, 120], u, v, 14) if u < 0.4
          return jitter([170, 70, 50], u, v, 16) if u > 0.64
          return jitter([150, 110, 70], u, v, 12)
        end
        jitter([22, 18, 16], u, v, 6)
      end

      # Leonardo da Vinci, Vitruvian Man
      def rn_vitruvian_man(u, v)
        a = 0.73
        paper = mix([232, 212, 170], [210, 185, 140], vnoise(u, v, 5) * 0.8)
        ink = [95, 65, 40]
        lw = 0.013
        cx = 0.5
        cy = 0.53
        r = 0.27
        # circle and square
        return ink if (dist(u, v, cx, cy, a) - r).abs < lw
        sq_b = cy + r
        sq_t = sq_b - 0.47
        sq_h = 0.235 / a
        in_sq = (u - cx).abs < sq_h + lw / a && v > sq_t - lw && v < sq_b + lw
        return ink if in_sq && (((u - cx).abs - sq_h).abs < lw / a || (v - sq_t).abs < lw || (v - sq_b).abs < lw)
        # the man: arms and legs in two positions
        body = mix(paper, ink, 0.55)
        sh_v = sq_t + 0.11
        hip_v = cy + 0.06
        limbs = [
          [cx, sh_v, cx - sq_h, sh_v], [cx, sh_v, cx + sq_h, sh_v],
          [cx, sh_v, cx - r * 0.77 / a, cy - r * 0.64], [cx, sh_v, cx + r * 0.77 / a, cy - r * 0.64],
          [cx - 0.02, hip_v, cx - 0.04, sq_b], [cx + 0.02, hip_v, cx + 0.04, sq_b],
          [cx, hip_v, cx - r * 0.5 / a, cy + r * 0.87], [cx, hip_v, cx + r * 0.5 / a, cy + r * 0.87]
        ]
        dh = dist(u, v, cx, sq_t + 0.05, a)
        return ink if dh < 0.045 && dh > 0.045 - lw * 1.5
        return body if dh < 0.045
        return body if rn_seg(u, v, cx, sh_v, cx, hip_v, a) < 0.045
        return body if limbs.any? { |x1, y1, x2, y2| rn_seg(u, v, x1, y1, x2, y2, a) < 0.016 }
        # lines of mirror-script text above and below
        if (v > 0.05 && v < 0.2) || (v > 0.86 && v < 0.96)
          row = v * 34
          return mix(paper, ink, 0.45) if (row - row.floor).between?(0.3, 0.75) && u > 0.07 && u < 0.93 && noise((u * 45).floor, row.floor) > 0.3
        end
        paper
      end

      # Michelangelo, The Creation of Adam
      def rn_creation_of_adam(u, v)
        a = 2.2
        skin = [215, 168, 120]
        # God's hand and Adam's hand, almost touching
        return mix(skin, [240, 210, 170], 0.3) if rn_seg(u, v, 0.515, 0.44, 0.63, 0.41, a) < 0.032
        return skin if rn_seg(u, v, 0.3, 0.5, 0.44, 0.455, a) < 0.03 || rn_seg(u, v, 0.44, 0.455, 0.455, 0.475, a) < 0.022
        # Adam reclining on the hill
        return [80, 55, 35] if dist(u, v, 0.105, 0.42, a) < 0.07 && v < 0.42 + (u - 0.1) * 1.5
        return skin if dist(u, v, 0.11, 0.44, a) < 0.07
        adam = [
          [0.14, 0.53, 0.26, 0.64, 0.1], # torso
          [0.26, 0.64, 0.33, 0.52, 0.055], # raised thigh
          [0.33, 0.52, 0.36, 0.76, 0.045], # shin
          [0.26, 0.65, 0.44, 0.82, 0.05], # extended leg
          [0.15, 0.52, 0.3, 0.5, 0.042], # upper arm resting on the knee
          [0.12, 0.55, 0.07, 0.7, 0.035] # the other arm propping him up
        ]
        adam.each do |x1, y1, x2, y2, w|
          d = rn_seg(u, v, x1, y1, x2, y2, a)
          return mix(skin, [150, 105, 70], d / w * 0.6 + (v - 0.5)) if d < w
        end
        # God borne in the red cloak with angels
        return [240, 236, 232] if dist(u, v, 0.61, 0.35, a) < 0.075 # white hair and beard
        return [215, 190, 200] if rn_seg(u, v, 0.64, 0.41, 0.85, 0.5, a) < 0.11 # pale robe
        return skin if rn_seg(u, v, 0.85, 0.5, 0.96, 0.58, a) < 0.05 # legs
        god = ellipse(u, v, 0.75, 0.43, 0.18, 0.4)
        if god < 1 && v < 0.82
          return [205, 85, 60] if god > 0.8
          [[0.7, 0.18], [0.77, 0.22], [0.84, 0.28], [0.72, 0.64], [0.8, 0.68], [0.68, 0.58], [0.87, 0.62]].each do |ax, ay|
            d = dist(u, v, ax, ay, a)
            return mix(skin, [180, 130, 90], d * 12) if d < 0.055
          end
          return jitter([140, 50, 40], u, v, 14)
        end
        return [90, 120, 90] if rn_seg(u, v, 0.86, 0.75, 0.99, 0.7, a) < 0.03 # green scarf
        # the green-brown hill
        hill = 0.62 + u * 0.55
        return jitter(mix([110, 115, 80], [70, 75, 50], (v - hill) * 3), u, v, 12) if v > hill || v > 0.94
        jitter(mix([205, 205, 195], [225, 220, 205], v), u, v, 8, 10)
      end

      # Raphael, The School of Athens
      def rn_school_of_athens(u, v)
        a = 1.54
        x = (u - 0.5) * a
        # the lunette frame
        return [60, 50, 40] if v < 0.77 && Math.hypot(x, v - 0.77) > 0.765
        # Plato (red) and Aristotle (blue) at the center of the steps
        [[0.475, [190, 60, 50]], [0.525, [60, 90, 160]]].each do |fx, col|
          part = rn_fig(u, v, fx, 0.42, 0.2, 0.05, a)
          return part == :head ? [220, 190, 160] : col if part
        end
        # crowds on both sides
        if v > 0.4 && v < 0.88
          16.times do |i|
            fx = 0.07 + i * 0.058
            next if (fx - 0.5).abs < 0.06
            [[0.43, 0.18], [0.62, 0.23]].each_with_index do |(top, h), row|
              jx = fx + (noise(i, row) - 0.5) * 0.04 + row * 0.02
              next if row == 1 && (jx - 0.5).abs < 0.12
              part = rn_fig(u, v, jx, top + noise(i, row + 5) * 0.03, h, 0.05, a)
              next unless part
              return [215, 180, 145] if part == :head
              return hsv(noise(i, row + 9) * 360, 0.45, 0.75)
            end
          end
        end
        # steps and floor
        if v > 0.6
          return Math.sin(v * 200) > 0.5 ? [180, 170, 150] : [210, 200, 180] if v < 0.7
          return (((u - 0.5) * 12 / (v + 0.1)).floor + (v * 20).floor).even? ? [205, 190, 160] : [160, 140, 115]
        end
        # receding barrel-vaulted arches
        arches = [[0.48, 0.5], [0.34, 0.47], [0.23, 0.45], [0.15, 0.44]]
        arches.each_with_index do |(r, c), k|
          open = v < c ? Math.hypot(x, v - c) < r : x.abs < r
          next if open
          if v < c
            d = Math.hypot(x, v - c)
            return [225, 215, 195] if d < r * 1.08
            ang = Math.atan2(v - c, x)
            return Math.sin(ang * 24) > 0.4 || Math.sin(d * 120) > 0.6 ? [150, 135, 110] : [185, 170, 145]
          end
          # piers, with dark statue niches on the outermost
          return [70, 60, 50] if k.zero? && (x.abs - 0.62).abs < 0.04 && v > 0.3 && v < 0.55
          prev_r = k.zero? ? 0.77 : arches[k - 1][0]
          return mix([200, 185, 160], [150, 135, 115], (x.abs - r) / (prev_r - r))
        end
        # bright sky through the last arch
        mix([150, 185, 215], [245, 245, 235], smooth(0.2, 0.55, v))
      end

      # Jan van Eyck, The Arnolfini Portrait
      def rn_arnolfini_portrait(u, v)
        a = 0.73
        # the little dog
        return [130, 95, 60] if ellipse(u, v, 0.5, 0.92, 0.07, 0.035) < 1
        # the man: huge dark hat, pale face, dark fur coat
        return [25, 18, 15] if ellipse(u, v, 0.33, 0.17, 0.11, 0.06) < 1 && v < 0.2
        return [225, 190, 160] if ellipse(u, v, 0.33, 0.25, 0.05, 0.055) < 1
        return [225, 190, 160] if dist(u, v, 0.43, 0.42, a) < 0.03 # raised hand
        coat = [[0.27, 0.3], [0.39, 0.3], [0.47, 0.55], [0.47, 0.95], [0.18, 0.95], [0.2, 0.55]]
        if inside?(u, v, coat)
          return [95, 70, 45] if ((u - 0.18).abs < 0.03 || (u - 0.47).abs < 0.03) && v > 0.5 # fur trim
          return jitter([55, 35, 45], u, v, 10)
        end
        # the woman in her green gown with white headdress
        return [240, 238, 230] if ellipse(u, v, 0.67, 0.25, 0.075, 0.06) < 1 && v < 0.27
        return [235, 205, 180] if ellipse(u, v, 0.66, 0.29, 0.045, 0.05) < 1
        gown = [[0.6, 0.34], [0.72, 0.34], [0.78, 0.55], [0.86, 0.95], [0.5, 0.95], [0.55, 0.6]]
        if inside?(u, v, gown)
          return [60, 90, 160] if v > 0.4 && v < 0.5 && (u - 0.6).abs < 0.03 # blue sleeve
          return mix([40, 110, 50], [20, 60, 30], Math.sin(u * 70 + v * 8) * 0.5 + 0.5)
        end
        return [235, 205, 180] if dist(u, v, 0.53, 0.43, a) < 0.03 # joined hands
        # the chandelier
        return [190, 150, 60] if v < 0.12 && ((u - 0.5).abs < 0.008 || (v > 0.06 && (u - 0.5).abs < 0.06 && Math.sin(u * 160) > 0.2))
        # the convex mirror on the back wall
        dm = dist(u, v, 0.5, 0.45, a)
        return [60, 40, 25] if dm < 0.07 && dm > 0.055
        return mix([170, 175, 165], [110, 100, 80], dm / 0.055) if dm < 0.055
        # the red bed at the right
        return jitter(Math.sin(u * 60) > 0.6 ? [130, 20, 20] : [170, 30, 30], u, v, 10) if u > 0.78 && v > 0.22
        # the window at the left
        if u < 0.15 && v > 0.08 && v < 0.55
          return [70, 50, 30] if (u - 0.07).abs < 0.01 || (v - 0.3).abs < 0.01
          return mix([220, 220, 200], [170, 175, 150], v)
        end
        return jitter([120, 85, 50], u, v, 12) if v > 0.82 # wooden floor
        jitter(mix([110, 85, 55], [80, 60, 40], (u - 0.5).abs * 2), u, v, 8)
      end

      # fur for the hare: brown with fine light and dark hairs
      def rn_fur(u, v, shade)
        n = brush(u, v, angle: 1.1, freq: 70.0, wobble: 0.6)
        base = mix([150, 115, 75], [85, 60, 40], shade)
        return mix(base, [215, 195, 160], 0.35) if n > 0.5
        n < -0.6 ? Color.scale(base, 0.7) : base
      end

      # Albrecht Dürer, Young Hare
      def rn_young_hare(u, v)
        a = 0.88
        # ears up and slightly back
        [[0.4, 0.37, 0.48, 0.08], [0.46, 0.38, 0.6, 0.1]].each_with_index do |(x1, y1, x2, y2), i|
          d = rn_seg(u, v, x1, y1, x2, y2, a)
          return rn_fur(u, v, 0.3 + i * 0.3) if d < 0.045 - 0.025 * Fx.clamp01((y1 - v) / (y1 - y2))
        end
        # head facing left
        if ellipse(u, v, 0.37, 0.47, 0.13, 0.11) < 1
          de = dist(u, v, 0.33, 0.44, a)
          return [240, 240, 235] if de < 0.025 && dist(u, v, 0.325, 0.435, a) < 0.008
          return [25, 20, 15] if de < 0.025
          return [220, 205, 175] if ellipse(u, v, 0.26, 0.53, 0.04, 0.03) < 1 # muzzle
          return rn_fur(u, v, 0.3)
        end
        # crouching body
        if ellipse(u, v, 0.57, 0.66, 0.28, 0.23) < 1 || ellipse(u, v, 0.34, 0.8, 0.09, 0.1) < 1
          return [225, 210, 180] if v > 0.78 && u < 0.45 && Math.sin(u * 90) > 0.6 # paws
          return rn_fur(u, v, Fx.clamp01(0.2 + (u - 0.3) * 0.9 + (v - 0.5) * 0.3))
        end
        # soft shadow on the cream ground
        return [205, 190, 160] if ellipse(u, v, 0.55, 0.9, 0.36, 0.05) < 1
        jitter([238, 228, 205], u, v, 6, 6)
      end

      # Albrecht Dürer, Self-Portrait at Twenty-Eight
      def rn_durer_self_portrait(u, v)
        a = 0.73
        skin = [220, 175, 135]
        cx = 0.5
        # face, frontal and symmetric
        if ellipse(u, v, cx, 0.33, 0.15, 0.15) < 1 && v > 0.21
          mx = (u - cx).abs
          return [40, 30, 20] if (v - 0.3).abs < 0.012 && (mx - 0.06).abs < 0.03 # eyes
          return [110, 70, 40] if v > 0.4 && mx < 0.11 - (v - 0.4) * 0.6 # beard and moustache
          return mix(skin, [160, 115, 80], mx * 3)
        end
        # long curly hair to the shoulders
        if ellipse(u, v, cx, 0.36, 0.3, 0.28) < 1 && v < 0.6
          curl = Math.sin(dist(u, v, cx + (u > cx ? 0.2 : -0.2), 0.45, a) * 90 + v * 20)
          return curl > 0.3 ? [175, 115, 60] : [120, 75, 40]
        end
        return [100, 65, 40] if v > 0.42 && v < 0.5 && (u - cx).abs < 0.08 # beard below the chin
        # fur collar and dark coat
        if v > 0.5 && (u - cx).abs < 0.15 + (v - 0.5) * 1.2
          return skin if ellipse(u, v, 0.47, 0.88, 0.06, 0.07) < 1 # hand at the fur
          if (u - cx).abs < 0.12 + (v - 0.5) * 0.3 || v < 0.6
            return mix([130, 90, 55], [80, 55, 35], brush(u, v, angle: 1.2, freq: 50.0) * 0.5 + 0.5)
          end
          return jitter([50, 38, 28], u, v, 8)
        end
        # the gold inscriptions on the dark ground
        return [190, 150, 70] if v.between?(0.3, 0.36) && u.between?(0.08, 0.16) && Math.sin(u * 200) > 0
        if u.between?(0.82, 0.95) && v.between?(0.26, 0.4) && (v * 40 - (v * 40).floor) < 0.4 && noise((u * 60).floor, (v * 40).floor) > 0.3
          return [180, 140, 65]
        end
        jitter([30, 22, 16], u, v, 6)
      end

      # Pieter Bruegel the Elder, Hunters in the Snow
      def rn_hunters_in_the_snow(u, v)
        a = 1.39
        dark = [40, 30, 25]
        # hunters with spears and their dogs trudging along the hill
        [[0.14, 0.66], [0.22, 0.69], [0.3, 0.72]].each do |hx, hy|
          return dark if (u - hx).abs < 0.016 && v > hy - 0.12 && v < hy
          return dark if dist(u, v, hx, hy - 0.13, a) < 0.02
          return dark if rn_seg(u, v, hx + 0.01, hy - 0.08, hx - 0.05, hy - 0.2, a) < 0.007 # spears
        end
        [[0.18, 0.72], [0.25, 0.75], [0.34, 0.77], [0.1, 0.7]].each do |dx, dy|
          return dark if ellipse(u, v, dx, dy, 0.025, 0.015) < 1 # dogs
        end
        # tall bare trees in a row down the slope
        hill = 0.5 + u * 0.6 + 0.015 * Math.sin(u * 25)
        [0.06, 0.19, 0.31, 0.43, 0.54].each_with_index do |tx, i|
          base = 0.55 + tx * 0.6
          next unless v < base
          x = u - tx - (base - v) * 0.03 * (i.even? ? 1 : -1)
          return dark if x.abs < 0.005 + (v / base) * 0.005
          return dark if v < base - 0.12 && Math.sin(v * 45 + x * 40 + i) > 0.93 && x.abs < 0.08 * (base - v)
        end
        if v > hill
          return [200, 80, 40] if dist(u, v, 0.04, 0.6, a) < 0.03 # the inn's fire
          return jitter(mix([190, 198, 200], [240, 240, 235], smooth(0.0, 0.08, v - hill)), u, v, 8)
        end
        # the valley: snow, frozen ponds with skaters, houses
        if v > 0.42 + 0.03 * Math.sin(u * 10)
          [[0.62, 0.75, 0.2, 0.1], [0.82, 0.62, 0.15, 0.06], [0.55, 0.6, 0.08, 0.04]].each do |px, py, rx, ry|
            next unless ellipse(u, v, px, py, rx, ry) < 1
            return dark if noise((u * 90).floor, (v * 70).floor) > 0.9
            return [140, 160, 150]
          end
          return [110, 60, 45] if noise((u * 40).floor, (v * 30).floor) > 0.86 # houses
          return mix([235, 238, 232], [200, 205, 200], v)
        end
        # jagged mountains at the right
        peaks = 0.33 + 0.08 * Math.sin(u * 30).abs - (u - 0.5) * 0.25
        return mix([235, 240, 238], [150, 165, 160], (v - peaks) * 8) if u > 0.5 && v > peaks
        return dark if dist(u, v, 0.62, 0.22, a) < 0.012 # the crow
        mix([160, 185, 175], [200, 210, 200], v * 2)
      end

      # Pieter Bruegel the Elder, The Tower of Babel
      def rn_tower_of_babel(u, v)
        cx = 0.47
        base_v = 0.78
        top_v = 0.12
        if v > top_v && v < base_v
          t = (base_v - v) / (base_v - top_v) # 0 at the bottom, 1 at the top
          hw = 0.36 * (1 - t * 0.78)
          # the unfinished top: a ragged crown with red brick exposed on the right
          hw *= 0.85 + 0.15 * Math.sin(u * 40) if t > 0.85
          if (u - cx).abs < hw
            band = t * 7.0
            f = band - band.floor
            sx = (u - cx) / hw # -1..1 across the cone
            light = 1.0 - 0.45 * Fx.clamp01(sx + 0.3)
            return Color.scale([160, 80, 60], light) if t > 0.7 && sx > 0.2 # raw brick
            return Color.scale([225, 210, 175], light) if f > 0.82 # ledge
            arch = Math.sin(Math.asin(sx.clamp(-1.0, 1.0)) * (22 - band * 2))
            return Color.scale([70, 55, 45], light) if f < 0.55 && f > 0.15 && arch > 0.2
            return jitter(Color.scale([200, 180, 140], light), u, v, 10)
          end
        end
        # the harbor with ships at the right
        if u > 0.72 && v > 0.62
          return [230, 225, 210] if Math.sin(u * 40) > 0.85 && v < 0.75 && v > 0.64 # sails
          return mix([120, 150, 160], [70, 100, 110], (v - 0.62) * 3)
        end
        # the city around the base
        if v > 0.66
          return [160, 85, 60] if noise((u * 60).floor, (v * 40).floor) > 0.8
          return jitter([170, 160, 130], u, v, 14)
        end
        # countryside to the horizon
        return jitter([120, 140, 110], u, v, 12) if v > 0.55 + 0.03 * Math.sin(u * 8)
        # clouds drifting around the upper tower
        return [235, 238, 240] if (v - 0.2 - u * 0.1).abs < 0.03 && Math.sin(u * 18) > 0
        mix([150, 180, 205], [215, 225, 225], v * 1.6)
      end

      # Hieronymus Bosch, The Garden of Earthly Delights
      def rn_garden_of_earthly_delights(u, v)
        a = 1.77
        # dark frames between the panels
        return [30, 22, 18] if u < 0.01 || u > 0.99 || (u - 0.255).abs < 0.008 || (u - 0.745).abs < 0.008
        if u < 0.255
          # Eden: green land, the pink fountain, a pond
          lu = u / 0.255
          return mix([200, 215, 220], [150, 180, 190], 1 - v * 3) if v < 0.28
          return [235, 160, 170] if (lu - 0.5).abs < 0.06 + (v > 0.48 ? 0.05 : 0) && v > 0.3 && v < 0.55
          return [90, 130, 150] if ellipse(lu, v, 0.5, 0.6, 0.3, 0.06) < 1
          return [230, 210, 190] if noise((u * 90).floor, (v * 60).floor) > 0.95 && v > 0.7
          return jitter(mix([110, 150, 80], [60, 100, 50], v), u, v, 14)
        end
        if u < 0.745
          # the garden: pale sky, pink and blue fantastical towers, crowds of tiny figures
          cu = (u - 0.255) / 0.49
          return mix([200, 215, 225], [170, 195, 210], 1 - v * 4) if v < 0.15
          if v < 0.32
            [[0.15, 0.04], [0.35, 0.03], [0.5, 0.05], [0.68, 0.03], [0.86, 0.04]].each_with_index do |(tx, tw), i|
              next unless (cu - tx).abs < tw + (v - 0.15) * 0.15
              return dist(cu, v, tx, 0.24, a * 0.5) < 0.04 ? [90, 120, 190] : (i.even? ? [230, 160, 175] : [120, 150, 200])
            end
            return mix([150, 190, 170], [120, 160, 130], (v - 0.15) * 4)
          end
          # the round pool with its cavalcade
          pe = ellipse(cu, v, 0.5, 0.42, 0.22, 0.07)
          return [100, 140, 170] if pe < 0.5
          return noise((u * 80).floor, (v * 50).floor) > 0.5 ? [210, 180, 160] : [150, 110, 80] if pe < 1
          [[0.2, 0.62], [0.78, 0.7], [0.45, 0.82]].each do |bx, by|
            return [110, 150, 210] if dist(cu, v, bx, by, a * 0.5) < 0.04 # blue spheres
          end
          n = noise((u * 100).floor, (v * 70).floor)
          return [240, 215, 200] if n > 0.86 # tiny pale figures
          return [200, 50, 50] if n > 0.83 # giant berries
          return jitter([150, 180, 120], u, v, 14)
        end
        # hell: darkness, fire glows, the tree-man, ice
        ru = (u - 0.745) / 0.255
        if v < 0.3
          glow = Math.sin(ru * 18) * 0.04 + 0.18
          return mix([250, 170, 60], [140, 30, 10], (glow - v).abs * 12) if (v - glow).abs < 0.06
          return [20, 14, 12]
        end
        return [230, 220, 210] if ellipse(ru, v, 0.5, 0.45, 0.18, 0.06) < 1 # tree-man's broken shell
        return [180, 175, 165] if ((ru - 0.42).abs < 0.03 && v > 0.48 && v < 0.65) || ((ru - 0.6).abs < 0.03 && v > 0.48 && v < 0.62)
        return [110, 130, 150] if v > 0.6 && v < 0.68 # frozen lake
        return [230, 120, 40] if noise((u * 80).floor, (v * 60).floor) > 0.94
        jitter([35, 28, 30], u, v, 10)
      end

      # Johannes Vermeer, Girl with a Pearl Earring
      def rn_girl_with_pearl_earring(u, v)
        a = 0.88
        skin = [235, 210, 180]
        # the pearl
        dp = dist(u, v, 0.4, 0.62, a)
        return [255, 255, 250] if dp < 0.012
        return [200, 205, 205] if dp < 0.028
        # blue turban and the yellow cloth hanging behind
        if ellipse(u, v, 0.48, 0.24, 0.17, 0.12) < 1 && v < 0.33 - (u - 0.48) * 0.2
          return mix([60, 90, 170], [30, 45, 100], smooth(0.4, 0.6, u))
        end
        if inside?(u, v, [[0.6, 0.14], [0.66, 0.16], [0.7, 0.5], [0.66, 0.6], [0.6, 0.45]])
          return mix([230, 200, 110], [170, 140, 60], (u - 0.58) * 6)
        end
        # face, lit from the left
        if ellipse(u, v, 0.5, 0.47, 0.145, 0.17) < 1 && v > 0.3
          return [60, 45, 35] if dist(u, v, 0.44, 0.44, a) < 0.022 || dist(u, v, 0.57, 0.44, a) < 0.02 # eyes
          return [195, 85, 80] if ellipse(u, v, 0.48, 0.59, 0.035, 0.018) < 1 # parted lips
          return mix(skin, [180, 145, 110], 0.5) if (u - 0.5).abs < 0.012 && v > 0.46 && v < 0.53 # nose shadow
          return mix(skin, [130, 100, 75], smooth(0.5, 0.64, u))
        end
        # the ochre jacket with a white collar
        shoulder = 0.68 + (u - 0.5).abs * 0.25
        if v > shoulder
          return [235, 232, 220] if v < shoulder + 0.05 && u > 0.33 && u < 0.62
          return mix([170, 140, 70], [90, 70, 40], smooth(0.3, 0.8, u))
        end
        return [40, 32, 25] if (u - 0.45).abs < 0.06 && v > 0.6 # shadowed neck
        jitter([22, 24, 18], u, v, 5)
      end

      # Johannes Vermeer, The Milkmaid
      def rn_milkmaid(u, v)
        a = 0.9
        skin = [225, 185, 145]
        # the milk stream into the bowl
        return [250, 245, 230] if (u - 0.425).abs < 0.008 && v > 0.58 && v < 0.66
        return [140, 85, 45] if ellipse(u, v, 0.42, 0.67, 0.08, 0.035) < 1 # bowl
        return [115, 72, 40] if ellipse(u, v, 0.45, 0.545, 0.05, 0.055) < 1 # jug
        # the maid
        return [240, 238, 225] if ellipse(u, v, 0.57, 0.17, 0.075, 0.07) < 1 && v < 0.19 # white cap
        return mix(skin, [190, 150, 115], smooth(0.55, 0.62, u)) if ellipse(u, v, 0.56, 0.23, 0.06, 0.065) < 1
        return [100, 125, 115] if rn_seg(u, v, 0.48, 0.33, 0.43, 0.48, a) < 0.05 || rn_seg(u, v, 0.67, 0.35, 0.56, 0.5, a) < 0.05 # sleeves
        return skin if rn_seg(u, v, 0.43, 0.48, 0.44, 0.54, a) < 0.035 || rn_seg(u, v, 0.56, 0.5, 0.49, 0.53, a) < 0.035
        return mix([245, 210, 80], [180, 140, 50], (u - 0.45) * 4) if inside?(u, v, [[0.46, 0.29], [0.67, 0.29], [0.7, 0.52], [0.47, 0.52]]) # yellow bodice
        if inside?(u, v, [[0.45, 0.5], [0.7, 0.5], [0.8, 0.98], [0.44, 0.98]])
          return [55, 85, 150] if u > 0.48 && u < 0.72 + (v - 0.5) * 0.1 && v < 0.88 # blue apron
          return [150, 50, 40]
        end
        # the table with bread and the green-blue cloth
        if v > 0.62 && u < 0.46 - (v - 0.62) * 0.2
          return [180, 120, 60] if ellipse(u, v, 0.18, 0.68, 0.1, 0.05) < 1 || ellipse(u, v, 0.3, 0.69, 0.05, 0.03) < 1 # bread
          return jitter([70, 100, 110], u, v, 14)
        end
        return [120, 90, 60] if u > 0.82 && v > 0.88 # foot warmer
        # the window at the left
        if u < 0.2 && v > 0.08 && v < 0.5
          return [80, 75, 60] if (u * 20 - (u * 20).floor) < 0.15 || (v * 20 - (v * 20).floor) < 0.15
          return mix([230, 235, 225], [180, 190, 180], v)
        end
        return [70, 60, 50] if dist(u, v, 0.1, 0.56, a) < 0.05 # basket on the wall
        jitter(mix([215, 210, 190], [170, 160, 140], smooth(0.2, 1.0, u)), u, v, 8, 12)
      end

      # Johannes Vermeer, View of Delft
      def rn_view_of_delft(u, v)
        # the low skyline: roofs, towers, the gate
        roof = 0.56 - 0.02 * Math.sin(u * 37).abs - (Math.sin(u * 91) > 0.5 ? 0.015 : 0)
        tower = ((u - 0.66).abs < 0.015 && v > 0.36) || ((u - 0.34).abs < 0.02 && v > 0.47) || ((u - 0.28).abs < 0.012 && v > 0.45)
        if v < 0.64 && (v > roof || tower)
          return [235, 210, 120] if (u - 0.66).abs < 0.015 # sunlit church tower
          return [60, 75, 90] if v < roof + 0.02 && u > 0.36 && u < 0.6 && !tower
          return noise((u * 70).floor, (v * 50).floor) > 0.6 ? [150, 70, 45] : [110, 75, 55]
        end
        # the bridge
        return [100, 80, 60] if v > 0.6 && v < 0.64 && u > 0.38 && u < 0.5
        # water with reflections
        if v > 0.64 && v < 0.86 - 0.03 * Math.sin(u * 6)
          refl = Math.sin(v * 160 + u * 4) > 0.3 ? 0.9 : 1.0
          base = u < 0.45 ? [65, 60, 55] : [70, 85, 95]
          return Color.scale(mix(base, [120, 140, 145], (v - 0.64) * 3), refl)
        end
        # the sandy bank with figures and boats
        if v >= 0.64
          return [40, 50, 70] if ((u - 0.1).abs < 0.008 || (u - 0.14).abs < 0.008) && v > 0.85 && v < 0.9
          return [60, 50, 40] if u > 0.8 && v < 0.88 && ellipse(u, v, 0.88, 0.86, 0.08, 0.025) < 1
          return jitter([200, 175, 130], u, v, 12)
        end
        # the big cloudy sky
        cloud = vnoise(u * 1.5, v * 3, 4)
        base = mix([90, 125, 175], [190, 205, 215], v * 1.8)
        return mix(base, [80, 85, 95], 0.7) if v < 0.15 && cloud > 0.45
        return mix(base, [245, 245, 240], (cloud - 0.5) * 3) if cloud > 0.5
        base
      end

      # Rembrandt, The Night Watch
      def rn_night_watch(u, v)
        a = 1.2
        # the captain in black with a red sash, and the lieutenant in gold
        return [230, 200, 170] if dist(u, v, 0.48, 0.42, a) < 0.035
        return [240, 240, 235] if ellipse(u, v, 0.48, 0.47, 0.04, 0.015) < 1 # ruff
        return [20, 15, 12] if dist(u, v, 0.48, 0.385, a) < 0.05 && v < 0.4 # hat
        if inside?(u, v, [[0.44, 0.48], [0.52, 0.48], [0.55, 0.95], [0.42, 0.95]])
          return [200, 40, 30] if (v - 0.52 - (u - 0.44) * 0.8).abs < 0.025 # sash
          return [20, 16, 14]
        end
        return [225, 195, 160] if dist(u, v, 0.6, 0.44, a) < 0.03
        return [235, 225, 200] if dist(u, v, 0.6, 0.41, a) < 0.04 && v < 0.42 # white plume hat
        return mix([250, 225, 130], [180, 140, 60], (u - 0.57) * 8) if inside?(u, v, [[0.57, 0.48], [0.64, 0.48], [0.66, 0.95], [0.56, 0.95]])
        # the glowing girl in gold at the left
        return [245, 220, 150] if dist(u, v, 0.33, 0.52, a) < 0.03
        return mix([255, 225, 120], [200, 160, 70], dist(u, v, 0.33, 0.62, a) * 10) if ellipse(u, v, 0.33, 0.64, 0.05, 0.1) < 1
        # pikes and the musketeers in the gloom
        if rn_seg(u, v, 0.15, 0.7, 0.3, 0.1, a) < 0.006 || rn_seg(u, v, 0.7, 0.6, 0.85, 0.05, a) < 0.006 || rn_seg(u, v, 0.62, 0.55, 0.55, 0.05, a) < 0.006
          return [90, 70, 45]
        end
        [[0.12, 0.45], [0.2, 0.38], [0.26, 0.5], [0.38, 0.3], [0.55, 0.28], [0.7, 0.35], [0.78, 0.42], [0.86, 0.38], [0.92, 0.5], [0.67, 0.25]].each_with_index do |(fx, fy), i|
          return mix([200, 160, 110], [110, 80, 50], i * 0.08) if dist(u, v, fx, fy, a) < 0.025
          return mix([70, 50, 30], [30, 22, 16], noise(i, 3)) if (u - fx).abs < 0.04 && v > fy + 0.02 && v < 0.95
        end
        return [55, 45, 40] if v > 0.92 # floor
        glow = Fx.clamp01(1 - dist(u, v, 0.5, 0.55, a) * 1.6)
        jitter(mix([22, 16, 10], [95, 70, 40], glow), u, v, 6)
      end

      # Diego Velázquez, Las Meninas
      def rn_las_meninas(u, v)
        a = 0.87
        skin = [230, 200, 170]
        # the Infanta in her wide pale gown
        return [235, 210, 150] if dist(u, v, 0.5, 0.58, a) < 0.04 && v < 0.58 # blond hair
        return skin if dist(u, v, 0.5, 0.6, a) < 0.035
        return mix([235, 230, 215], [190, 185, 170], (u - 0.42) * 5) if v > 0.64 && v < 0.92 && (u - 0.5).abs < 0.03 + (v - 0.64) * 0.55
        # the maids of honor
        [[0.38, 0.63, [150, 140, 110]], [0.62, 0.62, [120, 110, 90]]].each do |mx, my, col|
          return skin if dist(u, v, mx, my, a) < 0.03
          return col if v > my + 0.03 && v < 0.92 && (u - mx).abs < 0.03 + (v - my) * 0.3
        end
        # the dwarf and the dog at the right
        return skin if dist(u, v, 0.76, 0.7, a) < 0.03
        return [50, 55, 70] if v > 0.73 && v < 0.9 && (u - 0.76).abs < 0.05
        return [150, 120, 80] if ellipse(u, v, 0.78, 0.92, 0.09, 0.03) < 1
        # the painter before his canvas
        return skin if dist(u, v, 0.3, 0.42, a) < 0.03
        return [30, 25, 22] if v > 0.45 && v < 0.85 && (u - 0.3).abs < 0.04
        # the back of the huge canvas
        if u < 0.22 && v > 0.05 && v < 0.9
          return [70, 50, 35] if u > 0.2 || (v - 0.1).abs < 0.01
          return jitter([95, 70, 45], u, v, 10)
        end
        # the bright open doorway with a figure, and the mirror
        if (u - 0.62).abs < 0.035 && v > 0.36 && v < 0.55
          return [30, 25, 20] if (u - 0.62).abs < 0.01 && v > 0.42
          return [240, 220, 170]
        end
        return [170, 175, 170] if (u - 0.5).abs < 0.02 && v > 0.4 && v < 0.46 # the royal couple in the mirror
        return [40, 30, 22] if (u - 0.5).abs < 0.03 && v > 0.38 && v < 0.48
        # paintings hung high on the back wall
        return [45, 35, 25] if v > 0.12 && v < 0.27 && ((u - 0.4).abs < 0.08 || (u - 0.62).abs < 0.08)
        # light from the windows at the right
        return jitter(mix([80, 70, 55], [140, 120, 90], u), u, v, 8) if v > 0.9
        jitter(mix([60, 50, 38], [110, 95, 75], smooth(0.3, 1.0, u) * (1 - v * 0.5)), u, v, 8)
      end

      # Caravaggio, The Calling of Saint Matthew
      def rn_calling_of_saint_matthew(u, v)
        a = 1.06
        skin = [215, 170, 125]
        # Christ at the right edge pointing across the room
        return [200, 150, 110] if rn_seg(u, v, 0.82, 0.44, 0.66, 0.42, a) < 0.016
        return skin if dist(u, v, 0.86, 0.37, a) < 0.04
        return [130, 50, 40] if inside?(u, v, [[0.82, 0.42], [0.92, 0.42], [0.98, 0.95], [0.84, 0.95]])
        return [120, 100, 70] if inside?(u, v, [[0.7, 0.47], [0.8, 0.47], [0.84, 0.95], [0.68, 0.95]]) # Peter
        return skin if dist(u, v, 0.75, 0.43, a) < 0.035
        # the group at the table on the left, lit by the beam
        [[0.12, 0.38, [200, 170, 60]], [0.25, 0.4, [190, 70, 50]], [0.37, 0.36, [60, 80, 60]], [0.48, 0.4, [220, 200, 170]]].each do |fx, fy, col|
          return mix(skin, [255, 230, 190], 0.3) if dist(u, v, fx, fy, a) < 0.04
          return [30, 25, 20] if dist(u, v, fx, fy - 0.035, a) < 0.045 && v < fy - 0.01 # hats
          return col if (u - fx).abs < 0.06 && v > fy + 0.04 && v < 0.66
        end
        return [200, 160, 110] if v > 0.62 && v < 0.7 && u < 0.6 # table top
        return [70, 45, 35] if v > 0.7 && v < 0.95 && u < 0.6 && (u < 0.03 || (u - 0.55).abs < 0.02 || Math.sin(u * 30) > 0.8)
        # the window, dark
        if u > 0.38 && u < 0.62 && v > 0.08 && v < 0.32
          return [150, 130, 90] if (u - 0.5).abs < 0.008 || (v - 0.2).abs < 0.008 || u < 0.39 || u > 0.61
          return [40, 35, 28]
        end
        # the diagonal beam of light from the upper right
        beam = v - (0.05 + (1 - u) * 0.55)
        return jitter(mix([150, 125, 85], [95, 80, 55], -beam * 3), u, v, 8) if beam < 0.02 && beam > -0.28 && v < 0.62
        jitter([30, 26, 22], u, v, 6)
      end
    end

    piece(:birth_of_venus, "The Birth of Venus", "Sandro Botticelli", "c. 1485", aspect: 1.58) { |u, v| rn_birth_of_venus(u, v) }
    piece(:primavera, "Primavera", "Sandro Botticelli", "c. 1480", aspect: 1.55) { |u, v| rn_primavera(u, v) }
    piece(:last_supper, "The Last Supper", "Leonardo da Vinci", "1498", aspect: 1.9) { |u, v| rn_last_supper(u, v) }
    piece(:lady_with_ermine, "Lady with an Ermine", "Leonardo da Vinci", "c. 1490", aspect: 0.74) { |u, v| rn_lady_with_ermine(u, v) }
    piece(:vitruvian_man, "Vitruvian Man", "Leonardo da Vinci", "c. 1490", aspect: 0.73) { |u, v| rn_vitruvian_man(u, v) }
    piece(:creation_of_adam, "The Creation of Adam", "Michelangelo", "c. 1512", aspect: 2.2) { |u, v| rn_creation_of_adam(u, v) }
    piece(:school_of_athens, "The School of Athens", "Raphael", "1511", aspect: 1.54) { |u, v| rn_school_of_athens(u, v) }
    piece(:arnolfini_portrait, "The Arnolfini Portrait", "Jan van Eyck", "1434", aspect: 0.73) { |u, v| rn_arnolfini_portrait(u, v) }
    piece(:young_hare, "Young Hare", "Albrecht Dürer", "1502", aspect: 0.88) { |u, v| rn_young_hare(u, v) }
    piece(:durer_self_portrait, "Self-Portrait at Twenty-Eight", "Albrecht Dürer", "1500", aspect: 0.73) { |u, v| rn_durer_self_portrait(u, v) }
    piece(:hunters_in_the_snow, "Hunters in the Snow", "Pieter Bruegel the Elder", "1565", aspect: 1.39) { |u, v| rn_hunters_in_the_snow(u, v) }
    piece(:tower_of_babel, "The Tower of Babel", "Pieter Bruegel the Elder", "1563", aspect: 1.36) { |u, v| rn_tower_of_babel(u, v) }
    piece(:garden_of_earthly_delights, "The Garden of Earthly Delights", "Hieronymus Bosch", "c. 1500", aspect: 1.77) { |u, v| rn_garden_of_earthly_delights(u, v) }
    piece(:girl_with_pearl_earring, "Girl with a Pearl Earring", "Johannes Vermeer", "c. 1665", aspect: 0.88) { |u, v| rn_girl_with_pearl_earring(u, v) }
    piece(:milkmaid, "The Milkmaid", "Johannes Vermeer", "c. 1658", aspect: 0.9) { |u, v| rn_milkmaid(u, v) }
    piece(:view_of_delft, "View of Delft", "Johannes Vermeer", "c. 1661", aspect: 1.2) { |u, v| rn_view_of_delft(u, v) }
    piece(:night_watch, "The Night Watch", "Rembrandt", "1642", aspect: 1.2) { |u, v| rn_night_watch(u, v) }
    piece(:las_meninas, "Las Meninas", "Diego Velázquez", "1656", aspect: 0.87) { |u, v| rn_las_meninas(u, v) }
    piece(:calling_of_saint_matthew, "The Calling of Saint Matthew", "Caravaggio", "1600", aspect: 1.06) { |u, v| rn_calling_of_saint_matthew(u, v) }
  end
end
