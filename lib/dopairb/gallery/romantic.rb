# frozen_string_literal: true

module Dopairb
  module Gallery
    module Paint
      module_function

      # Friedrich, Wanderer above the Sea of Fog
      def wanderer_above_the_sea_of_fog(u, v)
        # the wanderer: dark coat, seen from behind, on the summit
        return [150, 95, 60] if ellipse(u, v, 0.50, 0.335, 0.035, 0.028) < 1 # windswept reddish hair
        return [40, 30, 30] if ellipse(u, v, 0.50, 0.365, 0.03, 0.02) < 1 # collar / neck
        coat_w = 0.06 - (v - 0.40).abs * 0.15
        return mix([35, 45, 40], [20, 25, 25], (u - 0.44) * 8) if v > 0.37 && v < 0.56 && (u - 0.50).abs < coat_w + 0.012
        if v >= 0.54 && v < 0.69
          leg_l = 0.475 - (v - 0.54) * 0.25
          leg_r = 0.525 + (v - 0.54) * 0.30
          return [30, 30, 30] if (u - leg_l).abs < 0.014 || (u - leg_r).abs < 0.014
        end
        return [60, 45, 35] if (u - (0.585 + (v - 0.48) * 0.1)).abs < 0.006 && v > 0.48 && v < 0.70 # walking stick
        # the dark rocky crag
        crag = 0.68 + (u - 0.50).abs * 0.55 + 0.03 * Math.sin(u * 37) + 0.02 * vnoise(u, v, 20)
        crag = [crag, 0.70].max
        return jitter(mix([45, 40, 38], [20, 18, 18], (v - crag) * 4), u, v, 12) if v > crag && u > 0.08 && u < 0.97
        # rocks poking through the fog
        return jitter([95, 95, 100], u, v, 10) if inside?(u, v, [[0.0, 0.62], [0.06, 0.52], [0.13, 0.55], [0.22, 0.66], [0.0, 0.70]])
        return jitter([90, 92, 100], u, v, 10) if inside?(u, v, [[0.66, 0.60], [0.74, 0.50], [0.80, 0.53], [0.90, 0.62], [0.78, 0.66]])
        return jitter([110, 112, 120], u, v, 8) if inside?(u, v, [[0.20, 0.52], [0.28, 0.47], [0.36, 0.53], [0.30, 0.56]])
        # distant mountains on the horizon
        mtn = 0.47 - 0.10 * smooth(0.55, 0.85, u) * (1 - smooth(0.9, 1.0, u) * 0.3) - 0.05 * Math.exp(-((u - 0.12) / 0.10)**2)
        return mix([150, 155, 170], [175, 180, 190], (v - mtn) * 5) if v > mtn && v < 0.50
        # the sea of fog
        if v > 0.46
          f = vnoise(u, v, 9) * 0.6 + vnoise(u + 3, v, 22) * 0.4
          return mix([205, 208, 210], [150, 155, 165], f * 1.2 - 0.2 + (v - 0.46) * 0.4)
        end
        # pale sky with soft clouds
        sky = ramp(v / 0.47, [150, 165, 185], [200, 205, 210], [235, 228, 210])
        c = vnoise(u, v, 6)
        c > 0.6 ? mix(sky, [235, 235, 232], (c - 0.6) * 1.5) : sky
      end

      # Friedrich, The Monk by the Sea
      def monk_by_the_sea(u, v)
        dune = 0.80 - (1 - u) * 0.06 + 0.012 * Math.sin(u * 9)
        if v > dune
          return [30, 30, 35] if (u - 0.33).abs < 0.008 && v < dune + 0.07 && v > dune - 0.0 # the monk
          return jitter(mix([215, 205, 175], [175, 160, 130], (v - dune) * 5), u, v, 8)
        end
        return [30, 30, 35] if (u - 0.33).abs < 0.008 && v > dune - 0.07 && v < dune + 0.01 # monk above the dune line
        return [30, 30, 35] if ellipse(u, v, 0.33, dune - 0.08, 0.009, 0.015) < 1
        if v > 0.71
          return mix([20, 35, 45], [35, 55, 70], Math.sin(u * 60 + v * 30) * 0.5 + 0.5) # dark sea
        end
        # vast sky: dark at the top, hazy light band above the horizon
        haze = smooth(0.30, 0.70, v)
        sky = ramp(haze, [55, 65, 75], [105, 120, 140], [170, 190, 205])
        c = vnoise(u, v, 5)
        sky = mix(sky, [210, 210, 205], (c - 0.55) * 1.5) if v > 0.45 && c > 0.55
        jitter(sky, u, v, 6, 12)
      end

      # Friedrich, The Sea of Ice
      def sea_of_ice(u, v)
        light = [225, 228, 225]
        mid = [165, 175, 180]
        shade = [105, 115, 125]
        # foreground slabs
        return jitter(mix([150, 140, 120], [110, 100, 85], (v - 0.85) * 6), u, v, 10) if v > 0.86 + 0.03 * Math.sin(u * 11)
        return jitter([205, 200, 185], u, v, 8) if inside?(u, v, [[0.0, 0.80], [0.18, 0.66], [0.40, 0.76], [0.30, 0.90], [0.0, 0.92]])
        return jitter([130, 130, 125], u, v, 8) if inside?(u, v, [[0.30, 0.90], [0.40, 0.76], [0.48, 0.80], [0.45, 0.92]])
        return jitter([190, 190, 180], u, v, 8) if inside?(u, v, [[0.55, 0.92], [0.70, 0.70], [0.98, 0.80], [1.0, 0.95]])
        # the crushed ship's stern, at the right of the pile
        return [70, 50, 35] if inside?(u, v, [[0.72, 0.62], [0.78, 0.46], [0.83, 0.48], [0.80, 0.66]])
        return [60, 45, 35] if (u - 0.80 + (v - 0.40) * 0.3).abs < 0.006 && v > 0.36 && v < 0.48 # broken mast
        # the pyramid of ice slabs
        if inside?(u, v, [[0.18, 0.80], [0.36, 0.45], [0.55, 0.10], [0.62, 0.18], [0.76, 0.48], [0.88, 0.74], [0.60, 0.82]])
          # a sun-lit left face and a shaded right face, banded into slabs
          side = u - (0.55 + (v - 0.10) * 0.15)
          band = Math.sin((u * 0.6 + v) * 30)
          base = side < 0 ? mix(light, mid, (v - 0.1) * 0.6) : mix(shade, mid, 0.2)
          base = mix(base, side < 0 ? mid : [80, 90, 100], 0.6) if band > 0.75
          return jitter(base, u, v, 8)
        end
        # low far ice field
        return jitter(mix([175, 180, 180], [140, 150, 155], (v - 0.6) * 4), u, v, 8) if v > 0.62 + 0.02 * Math.sin(u * 23)
        # cold sky
        sky = ramp(v / 0.62, [120, 140, 160], [165, 180, 195], [210, 215, 210])
        jitter(sky, u, v, 6, 8)
      end

      # Turner, The Fighting Temeraire
      def fighting_temeraire(u, v)
        horizon = 0.68
        sun_glow = Math.exp(-((u - 0.80) / 0.18)**2 - ((v - 0.64) / 0.20)**2)
        # background: sunset sky and the water reflecting it
        if v > horizon
          refl = sun_glow * 1.6 + Math.exp(-((u - 0.80) / 0.05)**2) * 0.7
          ripple = Math.sin(v * 120 + Math.sin(u * 20) * 2) > 0.3 ? 0.9 : 1.0
          bg = Color.scale(mix([95, 125, 140], [240, 140, 60], refl), ripple)
        elsif dist(u, v, 0.80, 0.64, 1.3) < 0.04
          bg = [255, 225, 140]
        else
          bg = mix([110, 150, 185], [185, 200, 205], v)
          bg = mix(bg, [235, 115, 40], smooth(0.40, 0.95, u) * smooth(0.25, 0.65, v))
          bg = mix(bg, [250, 200, 100], sun_glow)
          streak = Math.sin(v * 40 + Math.sin(u * 8) * 2)
          bg = mix(bg, [200, 60, 40], 0.5) if streak > 0.7 && u > 0.55 && v > 0.3
          bg = jitter(bg, u, v, 8, 10)
        end
        # the dark tugboat ahead of the old ship
        return [30, 28, 30] if inside?(u, v, [[0.34, 0.655], [0.52, 0.65], [0.50, 0.71], [0.36, 0.71]])
        return [25, 22, 22] if (u - 0.44).abs < 0.012 && v > 0.56 && v < 0.66
        # its red-orange smoke plume streaming up and back
        cx = 0.44 - (0.57 - v) * 0.55
        w = 0.02 + (0.57 - v) * 0.15
        if v < 0.57 && v > 0.22 && (u - cx).abs < w
          return mix([170, 60, 35], bg, (0.57 - v) * 1.4 + (u - cx).abs / w * 0.3)
        end
        # the ghostly old ship, pale against the sky
        ghost = [235, 228, 205]
        return mix(ghost, bg, 0.15 + (v - 0.58) * 2) if inside?(u, v, [[0.06, 0.58], [0.40, 0.57], [0.37, 0.69], [0.10, 0.70]])
        [0.13, 0.22, 0.31].each_with_index do |mx, i|
          top = [0.14, 0.08, 0.16][i]
          return mix(ghost, bg, 0.3) if (u - mx).abs < 0.007 && v > top && v < 0.58
          [0.22, 0.34, 0.46].each do |yy|
            next if yy < top + 0.04
            return mix(ghost, bg, 0.4) if (v - yy).abs < 0.009 && (u - mx).abs < 0.03 + (yy - 0.22) * 0.12
          end
        end
        bg
      end

      # Turner, Rain, Steam and Speed - The Great Western Railway
      def rain_steam_and_speed(u, v)
        haze = vnoise(u, v, 4) * 0.6 + vnoise(u + 5, v, 10) * 0.4
        # background: golden haze, blue patch top left, river and fields below
        if v > 0.58
          base = u < 0.55 ? mix([185, 175, 140], [140, 125, 95], (v - 0.58) * 3) : mix([140, 110, 65], [95, 70, 45], (v - 0.58) * 3)
          bg = jitter(mix(base, [215, 200, 150], haze * 0.4), u, v, 10)
        else
          bg = mix([230, 210, 145], [185, 170, 145], haze)
          bg = mix(bg, [125, 155, 185], smooth(0.40, 0.0, u + v * 0.7) * 0.8)
          bg = mix(bg, [250, 238, 195], Math.exp(-((u - 0.50) / 0.18)**2 - ((v - 0.30) / 0.18)**2) * 0.7)
          bg = jitter(bg, u, v, 8, 12)
        end
        # the old road bridge with arches, far left
        if u < 0.32 && v > 0.53 && v < 0.60
          return mix([160, 145, 115], bg, 0.4) if Math.sin(u * 55) < 0.3 || v < 0.545
        end
        # the railway bridge from the lower right, receding toward the left
        t = smooth(0.25, 1.0, u)
        deck_top = 0.50 + t * 0.16
        deck_bot = deck_top + 0.015 + t * 0.20
        fade = 0.80 - t * 0.75
        # the locomotive charging toward the viewer
        if ellipse(u, v, 0.78, 0.58, 0.085, 0.09) < 1 && v < deck_top + 0.06
          return [255, 190, 100] if dist(u, v, 0.78, 0.62, 1.3) < 0.018 # firebox glow
          return mix([35, 28, 25], bg, 0.1)
        end
        return [30, 25, 22] if (u - 0.78).abs < 0.016 && v > 0.43 && v < 0.52 # chimney
        return mix([200, 195, 185], bg, 0.6) if ellipse(u, v, 0.66, 0.41, 0.14, 0.05) < 1 # steam
        if u > 0.25 && v > deck_top && v < deck_bot
          return mix([90, 60, 35], bg, fade)
        end
        # piers under the bridge
        if u > 0.45 && v > deck_bot && Math.sin((u - 0.45) * 22) > 0.8
          return mix([110, 80, 50], bg, fade + 0.2)
        end
        bg
      end

      # Constable, The Hay Wain
      def hay_wain(u, v)
        # the hay wain and horses in the shallows
        return [150, 50, 35] if ellipse(u, v, 0.50, 0.69, 0.025, 0.035) < 1 && ellipse(u, v, 0.50, 0.69, 0.012, 0.018) > 1 # red wheel
        return [160, 115, 60] if inside?(u, v, [[0.40, 0.57], [0.60, 0.59], [0.59, 0.68], [0.42, 0.68]])
        return [190, 175, 140] if ellipse(u, v, 0.52, 0.66, 0.02, 0.025) < 1 # driver
        return [60, 45, 32] if inside?(u, v, [[0.29, 0.62], [0.41, 0.61], [0.41, 0.68], [0.30, 0.68]])
        return [60, 45, 32] if ((u - 0.31).abs < 0.009 || (u - 0.39).abs < 0.009) && v > 0.67 && v < 0.73
        return [55, 40, 30] if ellipse(u, v, 0.285, 0.605, 0.02, 0.03) < 1
        # Willy Lott's cottage on the left
        return [150, 65, 40] if inside?(u, v, [[0.0, 0.47], [0.07, 0.40], [0.18, 0.49], [0.0, 0.49]])
        if u < 0.17 && v >= 0.49 && v < 0.66
          return [70, 60, 50] if noise((u * 40).floor, (v * 30).floor) > 0.8
          return [205, 190, 160]
        end
        # the great trees over the cottage and along the left half
        tree_l = v > 0.06 + 0.35 * smooth(0.15, 0.55, u) + 0.04 * Math.sin(u * 30) && v < 0.64 && u < 0.58
        tree_r = u > 0.87 + 0.04 * Math.sin(v * 13) && v > 0.30 && v < 0.62
        if tree_l || tree_r
          f = vnoise(u, v, 14)
          return mix([35, 50, 28], [100, 115, 55], f * f * 1.4)
        end
        # far trees and the sunlit meadow on the right
        return mix([60, 85, 50], [90, 110, 60], vnoise(u, v, 20)) if v > 0.51 - 0.025 * Math.sin(u * 20).abs && v < 0.56
        return jitter(mix([185, 180, 95], [125, 145, 60], (v - 0.56) * 10), u, v, 10) if v >= 0.56 && v < 0.63 && u > 0.36
        # the river, reflecting the trees and sky
        if v >= 0.62 && v < 0.88 - 0.10 * u
          ripple = u > 0.45 && Math.sin(v * 120 + Math.sin(u * 15) * 3) > 0.75
          base = u < 0.5 ? mix([85, 85, 60], [60, 60, 45], (v - 0.62) * 4) : mix([150, 160, 160], [95, 100, 85], (v - 0.62) * 4)
          return ripple ? mix(base, [210, 210, 200], 0.3) : base
        end
        # banks
        return jitter(u < 0.45 ? [110, 95, 55] : [85, 110, 50], u, v, 14) if v >= 0.62
        # summer sky with big cumulus clouds
        sky = mix([75, 115, 180], [150, 175, 205], v * 1.6)
        c = vnoise(u, v, 4) * 0.7 + vnoise(u, v, 11) * 0.3
        return mix([250, 245, 235], [150, 150, 150], (c - 0.5) * 2.5 + v * 0.5) if c > 0.48
        sky
      end

      # Delacroix, Liberty Leading the People
      def liberty_leading_the_people(u, v)
        # the tricolor flag on its pole, raised high
        wave = 0.015 * Math.sin(v * 25 + u * 10)
        if v > 0.04 + wave && v < 0.25 + wave && u > 0.47 && u < 0.66
          return [35, 55, 150] if u < 0.53
          return [240, 235, 220] if u < 0.59
          return [205, 35, 35]
        end
        return [70, 50, 35] if (u - 0.47 + (v - 0.04) * 0.08).abs < 0.007 && v > 0.03 && v < 0.30
        # Liberty: raised arm, head, golden dress
        return [230, 195, 155] if (u - 0.462 + (v - 0.22) * 0.25).abs < 0.014 && v > 0.21 && v < 0.33 # arm
        return [40, 30, 25] if ellipse(u, v, 0.425, 0.315, 0.03, 0.035) < 1 && u < 0.42 # hair
        return [230, 195, 155] if ellipse(u, v, 0.43, 0.32, 0.026, 0.035) < 1
        return [40, 30, 25] if (v - 0.42 - (0.40 - u) * 1.0).abs < 0.01 && u > 0.31 && u < 0.41 # musket
        if inside?(u, v, [[0.40, 0.35], [0.47, 0.35], [0.52, 0.55], [0.58, 0.80], [0.36, 0.80], [0.39, 0.55]])
          return jitter(mix([240, 220, 160], [175, 150, 90], (v - 0.35) * 1.5 + (u - 0.44) * 2.5), u, v, 10)
        end
        # the man in a top hat at left, the boy with pistols at right
        return [25, 22, 22] if inside?(u, v, [[0.25, 0.32], [0.31, 0.32], [0.31, 0.40], [0.25, 0.40]])
        return [24, 22, 22] if inside?(u, v, [[0.23, 0.40], [0.33, 0.40], [0.33, 0.415], [0.23, 0.415]])
        return [215, 180, 140] if ellipse(u, v, 0.28, 0.44, 0.022, 0.03) < 1
        return [35, 30, 30] if inside?(u, v, [[0.22, 0.47], [0.34, 0.47], [0.37, 0.80], [0.18, 0.80]])
        return [60, 45, 40] if ellipse(u, v, 0.62, 0.38, 0.022, 0.022) < 1 # beret
        return [215, 180, 140] if ellipse(u, v, 0.62, 0.42, 0.02, 0.03) < 1
        return [45, 50, 80] if inside?(u, v, [[0.58, 0.45], [0.66, 0.45], [0.69, 0.78], [0.57, 0.78]])
        return [40, 35, 30] if (v - 0.36 - (u - 0.66) * 1.2).abs < 0.012 && u > 0.65 && u < 0.71 # raised pistol arm
        # the crowd rising toward her in a pyramid
        if inside?(u, v, [[0.0, 0.70], [0.12, 0.55], [0.30, 0.48], [0.45, 0.42], [0.62, 0.50], [0.85, 0.55], [1.0, 0.68], [1.0, 0.85], [0.0, 0.85]])
          return jitter(mix([75, 65, 55], [40, 35, 30], vnoise(u, v, 14)), u, v, 10)
        end
        # the barricade and fallen figures at the bottom
        if v > 0.76 - 0.06 * Math.sin(u * 3.2)
          return jitter([175, 165, 145], u, v, 12) if ellipse(u, v, 0.24, 0.90, 0.12, 0.035) < 1
          return jitter([160, 150, 135], u, v, 12) if ellipse(u, v, 0.76, 0.89, 0.09, 0.03) < 1
          return jitter(mix([95, 75, 50], [50, 40, 30], vnoise(u, v, 10)), u, v, 12)
        end
        # Notre-Dame's towers in the haze
        return [150, 135, 110] if v > 0.38 && (u > 0.80 && u < 0.84 || u > 0.88 && u < 0.92)
        # smoke-filled sky, brightest behind Liberty
        glow = Math.exp(-((u - 0.47) / 0.22)**2 - ((v - 0.35) / 0.35)**2)
        smoke = vnoise(u, v, 5)
        sky = mix([105, 90, 65], [215, 200, 150], smoke * 0.6 + glow * 0.6)
        jitter(sky, u, v, 10, 14)
      end

      # Géricault, The Raft of the Medusa
      def raft_of_the_medusa(u, v)
        # the man at the apex waving a cloth
        return [215, 190, 160] if ellipse(u, v, 0.82, 0.20, 0.035, 0.03) < 1 && ((u * 30 + v * 20).floor.even?)
        return [210, 150, 110] if ellipse(u, v, 0.80, 0.27, 0.02, 0.03) < 1
        return [190, 140, 100] if (u - 0.80 - (0.28 - v) * 0.3).abs < 0.008 && v > 0.22 && v < 0.30
        # the pyramid of figures rising to the right
        pyramid = [[0.30, 0.84], [0.42, 0.66], [0.55, 0.55], [0.66, 0.44], [0.76, 0.32], [0.82, 0.30], [0.86, 0.84]]
        if inside?(u, v, pyramid)
          f = vnoise(u, v, 18)
          return f > 0.55 ? mix([200, 150, 100], [150, 100, 65], v) : mix([90, 60, 40], [50, 35, 25], v)
        end
        # the sail and mast at left
        return [50, 40, 30] if (u - 0.30).abs < 0.007 && v > 0.12 && v < 0.84
        return [55, 45, 35] if (v - 0.12 - (u - 0.30) * 1.4).abs < 0.005 && u > 0.30 && u < 0.55 # rope
        return [55, 45, 35] if (v - 0.12 - (0.30 - u) * 2.2).abs < 0.005 && u < 0.30 && u > 0.12 # rope
        if inside?(u, v, [[0.31, 0.16], [0.44, 0.24], [0.42, 0.62], [0.31, 0.64]])
          return jitter(mix([175, 150, 110], [120, 100, 75], (u - 0.31) * 6), u, v, 10)
        end
        # the tilting raft
        raft_v = 0.86 - (u - 0.2) * 0.08
        if v > raft_v && v < raft_v + 0.06 && u > 0.12 && u < 0.92
          return [70, 50, 30]
        end
        # stormy sea
        sea = 0.62 - 0.12 * Math.exp(-((u - 0.10) / 0.12)**2)
        if v > sea
          wave = Math.sin(u * 25 + v * 40 + Math.sin(u * 6) * 3)
          return mix([22, 30, 28], [65, 75, 60], wave * 0.3 + 0.4 - (v - sea))
        end
        # dark sky with a light patch at the horizon on the right
        light = Math.exp(-((u - 0.85) / 0.18)**2 - ((v - 0.55) / 0.15)**2)
        sky = mix([40, 40, 35], [85, 80, 60], vnoise(u, v, 5))
        sky = mix(sky, [235, 210, 140], light)
        jitter(sky, u, v, 8, 12)
      end

      # Goya, The Third of May 1808
      def third_of_may(u, v)
        lamp = Math.exp(-((u - 0.45) / 0.25)**2 - ((v - 0.75) / 0.30)**2)
        # the man with raised arms, white shirt and yellow trousers
        return [240, 235, 220] if ellipse(u, v, 0.34, 0.50, 0.045, 0.08) < 1
        return [240, 235, 220] if (u - 0.30 + (0.45 - v) * 0.35).abs < 0.012 && v > 0.32 && v < 0.46 # left arm
        return [240, 235, 220] if (u - 0.38 - (0.45 - v) * 0.35).abs < 0.012 && v > 0.32 && v < 0.46 # right arm
        return [80, 60, 40] if ellipse(u, v, 0.34, 0.415, 0.022, 0.03) < 1 # head
        return [225, 190, 60] if ellipse(u, v, 0.34, 0.63, 0.05, 0.07) < 1 # trousers, kneeling
        # the lantern on the ground
        return [255, 245, 200] if inside?(u, v, [[0.46, 0.74], [0.56, 0.74], [0.57, 0.86], [0.45, 0.86]])
        return [60, 45, 30] if inside?(u, v, [[0.44, 0.86], [0.58, 0.86], [0.58, 0.88], [0.44, 0.88]])
        # other victims huddled around him (dark)
        return [60, 45, 35] if ellipse(u, v, 0.22, 0.58, 0.06, 0.13) < 1
        return [70, 55, 40] if ellipse(u, v, 0.43, 0.60, 0.04, 0.12) < 1
        return [55, 45, 35] if ellipse(u, v, 0.20, 0.86, 0.12, 0.04) < 1
        # the firing squad: a dark row seen from behind, rifles aimed left
        return [40, 35, 30] if v > 0.54 && v < 0.565 && u > 0.47 && u < 0.62 && ((u * 60).floor % 3 != 0)
        [0.62, 0.70, 0.78, 0.86, 0.94].each do |sx|
          return [25, 25, 25] if ellipse(u, v, sx, 0.41, 0.03, 0.035) < 1 # shako
          if ellipse(u, v, sx + 0.01, 0.62, 0.055, 0.20) < 1
            return mix([90, 80, 60], [45, 40, 32], (u - sx + 0.05) * 8)
          end
        end
        return [45, 40, 32] if v > 0.55 && v < 0.85 && u > 0.6
        # lit ground
        ground = 0.70 - 0.25 * smooth(0.6, 0.0, u) * 0 # flat
        if v > ground
          return mix([60, 45, 30], [210, 175, 110], lamp)
        end
        # the dark hill at left, the town and the night sky
        hill = 0.20 + u * 0.8
        return mix([40, 35, 25], [110, 90, 60], lamp * 0.8) if v > hill
        return [55, 50, 50] if v > 0.30 && (u > 0.66 && u < 0.72 || u > 0.74 && u < 0.85 && v > 0.36) # town buildings
        return [50, 45, 45] if (u - 0.69).abs < 0.012 && v > 0.22 # church tower
        mix([15, 15, 20], [35, 35, 40], v)
      end

      # Millet, The Gleaners
      def the_gleaners(u, v)
        # three peasant women in the foreground: two bent low, one half-rising
        women = [
          [0.22, 0.68, [55, 85, 150], [150, 125, 95], [80, 85, 105], false],
          [0.48, 0.70, [195, 45, 40], [95, 105, 130], [140, 105, 70], false],
          [0.75, 0.60, [105, 65, 40], [120, 105, 90], [100, 85, 70], true],
        ]
        women.each do |cx, cy, scarf, top, skirt, upright|
          if upright
            return scarf if ellipse(u, v, cx - 0.04, cy - 0.17, 0.03, 0.04) < 1
            return top if ellipse(u, v, cx, cy - 0.06, 0.05, 0.10) < 1
            return [170, 130, 95] if (u - (cx - 0.05 + (v - 0.55) * 0.1)).abs < 0.01 && v > 0.55 && v < 0.76
            return skirt if inside?(u, v, [[cx - 0.05, cy - 0.02], [cx + 0.05, cy - 0.02], [cx + 0.07, 0.90], [cx - 0.05, 0.90]])
          else
            # the back slopes down toward the head near the ground
            x = u - cx
            y = v - cy
            a = -0.3
            lx = x * Math.cos(a) + y * Math.sin(a)
            ly = -x * Math.sin(a) + y * Math.cos(a)
            return scarf if ellipse(u, v, cx - 0.14, cy + 0.07, 0.035, 0.05) < 1
            return top if (lx / 0.12)**2 + (ly / 0.075)**2 < 1
            return skirt if inside?(u, v, [[cx + 0.0, cy - 0.02], [cx + 0.10, cy + 0.02], [cx + 0.11, 0.93], [cx - 0.01, 0.93]])
            return [170, 130, 95] if (u - (cx - 0.10)).abs < 0.014 && v > cy + 0.05 && v < 0.92 # arm to the stubble
          end
        end
        # distant haystacks and the harvest
        stack = lambda do |sx, w, h|
          ellipse(u, v, sx, 0.46, w, h) < 1 && v < 0.46
        end
        return mix([200, 165, 100], [150, 115, 65], (u - 0.80) * 8) if stack.call(0.86, 0.06, 0.17)
        return mix([200, 165, 100], [150, 115, 65], (u - 0.66) * 10) if stack.call(0.70, 0.04, 0.11)
        return [175, 140, 85] if stack.call(0.58, 0.025, 0.06)
        return [110, 85, 60] if v > 0.41 && v < 0.46 && noise((u * 70).floor, 1) > 0.85 # tiny workers
        if v > 0.38
          base = mix([225, 205, 145], [180, 145, 90], smooth(0.38, 0.52, v))
          base = mix(base, [150, 115, 75], smooth(0.5, 0.95, v))
          stub = Math.sin(u * 160 + v * 40) > 0.6 && v > 0.55 ? 0.85 : 1.0
          return Color.scale(jitter(base, u, v, 10), stub)
        end
        # pale hazy sky
        jitter(mix([215, 215, 200], [235, 225, 195], v * 3), u, v, 6, 8)
      end

      # Millet, The Angelus
      def the_angelus(u, v)
        horizon = 0.52
        # the man, head bowed, hat held at his chest
        return [50, 40, 32] if ellipse(u, v, 0.31, 0.27, 0.032, 0.04) < 1
        return [65, 55, 50] if inside?(u, v, [[0.26, 0.29], [0.35, 0.30], [0.38, 0.60], [0.24, 0.60]])
        return [40, 32, 25] if ellipse(u, v, 0.34, 0.40, 0.03, 0.035) < 1 # hat in hands
        return [55, 42, 35] if inside?(u, v, [[0.25, 0.60], [0.37, 0.60], [0.36, 0.86], [0.26, 0.86]])
        # the woman, hands clasped, head bowed under a pale cap
        return [175, 165, 145] if ellipse(u, v, 0.645, 0.30, 0.03, 0.03) < 1
        return [95, 70, 60] if inside?(u, v, [[0.61, 0.32], [0.69, 0.32], [0.71, 0.54], [0.60, 0.54]])
        return [110, 60, 45] if inside?(u, v, [[0.60, 0.54], [0.71, 0.54], [0.75, 0.86], [0.57, 0.86]])
        # pitchfork stuck in the ground at left
        return [55, 42, 30] if (u - 0.18 + (v - 0.5) * 0.06).abs < 0.007 && v > 0.36 && v < 0.86
        # basket between them, wheelbarrow with sacks at right
        return [115, 85, 50] if ellipse(u, v, 0.47, 0.84, 0.04, 0.03) < 1
        return [140, 120, 85] if ellipse(u, v, 0.87, 0.63, 0.06, 0.045) < 1
        return [70, 55, 40] if (v - 0.67).abs < 0.01 && u > 0.78 && u < 0.94
        # church steeple on the horizon
        return [85, 75, 80] if (u - 0.84).abs < 0.008 && v > 0.44 && v < horizon || (u - 0.84).abs < 0.03 && v > 0.49 && v < horizon
        if v > horizon
          furrow = Math.sin(v * 200 / (v - 0.4)) > 0.5 ? 0.85 : 1.0
          base = mix([125, 105, 70], [60, 48, 32], (v - horizon) * 2.2)
          return Color.scale(jitter(base, u, v, 10), furrow)
        end
        # warm evening sky, glowing at the horizon
        sky = ramp(v / horizon, [125, 125, 115], [195, 175, 135], [245, 210, 140])
        jitter(sky, u, v, 6, 8)
      end

      # Whistler, Arrangement in Grey and Black No. 1
      def whistlers_mother(u, v)
        # the mother, seated in profile facing left
        return [235, 235, 230] if ellipse(u, v, 0.61, 0.36, 0.045, 0.05) < 1 && v < 0.38 || ellipse(u, v, 0.63, 0.40, 0.035, 0.05) < 1 && u > 0.62 # white cap
        return [225, 200, 180] if ellipse(u, v, 0.59, 0.41, 0.03, 0.04) < 1 # face
        return [230, 230, 225] if ellipse(u, v, 0.53, 0.66, 0.035, 0.025) < 1 # handkerchief in the lap
        body = inside?(u, v, [[0.57, 0.44], [0.66, 0.44], [0.72, 0.60], [0.86, 0.92], [0.44, 0.92], [0.48, 0.70], [0.56, 0.60]])
        return [25, 25, 28] if body
        return [40, 35, 30] if inside?(u, v, [[0.66, 0.50], [0.80, 0.48], [0.82, 0.70], [0.72, 0.70]]) # chair back
        return [60, 50, 40] if inside?(u, v, [[0.38, 0.88], [0.50, 0.88], [0.50, 0.94], [0.38, 0.94]]) # footstool
        # the curtain at left, dark with a pale pattern
        if u < 0.22 + 0.01 * Math.sin(v * 20)
          return [175, 170, 155] if noise((u * 60).floor, (v * 45).floor) > 0.82
          return Math.sin(u * 80) > 0.6 ? [45, 42, 40] : [30, 28, 27]
        end
        # the framed picture on the wall
        if u > 0.28 && u < 0.50 && v > 0.16 && v < 0.40
          return [20, 20, 20] if u < 0.30 || u > 0.48 || v < 0.18 || v > 0.38
          return [225, 222, 210] if u < 0.32 || u > 0.46 || v < 0.21 || v > 0.35
          return mix([110, 110, 105], [170, 168, 160], vnoise(u, v, 30))
        end
        # floor and wall
        return jitter([90, 85, 75], u, v, 8) if v > 0.88
        return [60, 58, 55] if (v - 0.76).abs < 0.008
        jitter([150, 148, 140], u, v, 5, 8)
      end

      # Aivazovsky, The Ninth Wave
      def ninth_wave(u, v)
        sun_u = 0.55
        sun_v = 0.38
        glow = Math.exp(-(dist(u, v, sun_u, sun_v, 1.4) / 0.25)**2)
        # survivors on the broken mast, lower left
        mast_v = 0.80 - (u - 0.10) * 0.25
        if u > 0.08 && u < 0.45 && (v - mast_v).abs < 0.018
          return [45, 30, 20]
        end
        [0.16, 0.23, 0.31, 0.38].each do |fx|
          mv = 0.80 - (fx - 0.10) * 0.25
          return [60, 40, 35] if ellipse(u, v, fx, mv - 0.04, 0.018, 0.04) < 1
          return [120, 50, 40] if ellipse(u, v, fx, mv - 0.085, 0.012, 0.015) < 1
        end
        # the great wave rising at left, lit through by the sun
        crest = 0.55 - 0.25 * Math.exp(-((u - 0.25) / 0.17)**2)
        sea = 0.58 + 0.03 * Math.sin(u * 18)
        wave_top = [crest, sea].min
        if v > wave_top
          if v < wave_top + 0.035 && Math.sin(u * 60) > -0.3
            return mix([250, 240, 200], [210, 220, 190], (v - wave_top) * 20) # foam crest
          end
          translucent = Math.exp(-((v - wave_top - 0.08) / 0.10)**2) * (0.5 + glow)
          streak = Math.sin(u * 30 + v * 70 + Math.sin(u * 7) * 3)
          base = mix([30, 70, 60], [140, 200, 120], translucent)
          base = mix(base, [20, 40, 40], smooth(0.75, 1.0, v))
          base = mix(base, [235, 230, 190], 0.5) if streak > 0.85
          return jitter(base, u, v, 8)
        end
        # sky: sun glowing through stormy air
        return [255, 245, 180] if dist(u, v, sun_u, sun_v, 1.4) < 0.045
        sky = ramp(v / 0.6, [80, 60, 60], [200, 120, 80], [240, 180, 90])
        sky = mix(sky, [255, 220, 120], glow)
        cl = vnoise(u, v, 5)
        sky = mix(sky, [110, 80, 80], (cl - 0.5) * 1.2) if cl > 0.5 && v < 0.35
        jitter(sky, u, v, 8, 10)
      end

      # Fragonard, The Swing
      def the_swing(u, v)
        # the woman in a billowing pink dress, the focus of the scene
        dress = ellipse(u, v, 0.58, 0.52, 0.17, 0.10)
        if dress < 1
          frill = Math.sin(u * 50 + v * 40) > 0.6
          return frill ? [255, 200, 205] : mix([235, 120, 140], [250, 160, 175], 1 - dress)
        end
        return [150, 115, 85] if ellipse(u, v, 0.66, 0.35, 0.04, 0.035) < 1 && u > 0.65 # hair
        return [245, 210, 190] if ellipse(u, v, 0.65, 0.36, 0.035, 0.035) < 1 # head
        return [225, 110, 130] if ellipse(u, v, 0.63, 0.42, 0.045, 0.04) < 1 # bodice
        return [245, 215, 195] if (v - 0.52 - (u - 0.41) * 0.5).abs < 0.018 && u > 0.33 && u < 0.42 # leg kicked up-left
        return [250, 130, 150] if ellipse(u, v, 0.27, 0.25, 0.035, 0.022) < 1 # the flying shoe
        # swing ropes running up to the upper left
        return [215, 190, 130] if (u - 0.50 + (0.47 - v) * 0.45).abs < 0.014 && v < 0.47
        return [215, 190, 130] if (u - 0.66 + (0.44 - v) * 0.45).abs < 0.014 && v < 0.44
        # the hidden admirer in the bushes at lower left, reaching up
        return [245, 210, 185] if ellipse(u, v, 0.18, 0.76, 0.035, 0.03) < 1
        return [225, 215, 180] if (v - 0.73 + (u - 0.22) * 1.1).abs < 0.018 && u > 0.21 && u < 0.33 # raised arm
        return [190, 185, 150] if ellipse(u, v, 0.10, 0.82, 0.10, 0.04) < 1
        # pale sky gap at top right
        gap = ellipse(u, v, 0.92, 0.10, 0.18, 0.16)
        return mix([225, 230, 215], [185, 200, 190], gap) if gap < 1 && vnoise(u, v, 12) < 0.7
        # pool of warm light behind her, dark lush trees framing everything
        light = Math.exp(-((u - 0.62) / 0.30)**2 - ((v - 0.48) / 0.28)**2)
        leaf = vnoise(u, v, 16) * 0.6 + vnoise(u, v, 5) * 0.4
        green = mix([15, 30, 15], [80, 105, 45], leaf * leaf)
        return mix(green, [215, 190, 120], light * 1.1 - 0.2 + leaf * 0.2) if light > 0.3
        jitter(mix(green, [120, 130, 70], light * 0.8), u, v, 8)
      end

      # David, Napoleon Crossing the Alps
      def napoleon_crossing_the_alps(u, v)
        # the billowing gold cloak streaming up and to the right
        cloak = inside?(u, v, [[0.50, 0.32], [0.62, 0.15], [0.80, 0.08], [0.92, 0.18], [0.80, 0.28], [0.70, 0.40], [0.56, 0.48]])
        return mix([240, 170, 50], [180, 90, 30], vnoise(u, v, 12) * 1.2) if cloak
        # the pointing arm
        return [40, 45, 80] if (v - 0.30 + (0.45 - u) * 1.1).abs < 0.018 && u > 0.33 && u < 0.47
        return [230, 200, 170] if ellipse(u, v, 0.32, 0.165, 0.015, 0.015) < 1
        # bicorne hat and face
        return [25, 25, 25] if ellipse(u, v, 0.49, 0.24, 0.06, 0.022) < 1
        return [230, 195, 160] if ellipse(u, v, 0.49, 0.285, 0.025, 0.03) < 1
        # rider's body
        return [45, 50, 90] if inside?(u, v, [[0.45, 0.31], [0.54, 0.31], [0.57, 0.48], [0.45, 0.50]])
        return [210, 200, 170] if inside?(u, v, [[0.47, 0.48], [0.57, 0.48], [0.62, 0.58], [0.52, 0.58]]) # breeches
        return [30, 25, 20] if ellipse(u, v, 0.62, 0.62, 0.025, 0.05) < 1 # boot
        # the rearing white horse on a diagonal
        return [70, 60, 50] if ellipse(u, v, 0.24, 0.40, 0.04, 0.10) < 1 && u < 0.26 # mane
        horse = ellipse(u, v, 0.47, 0.56, 0.20, 0.09) < 1 ||
                inside?(u, v, [[0.18, 0.36], [0.26, 0.30], [0.34, 0.48], [0.30, 0.56], [0.20, 0.44]]) || # neck and head
                ellipse(u, v, 0.15, 0.40, 0.05, 0.04) < 1 ||
                (u - 0.26 - (v - 0.56) * 0.6).abs < 0.02 && v > 0.56 && v < 0.70 || # forelegs raised
                (u - 0.62 - (v - 0.62) * 0.3).abs < 0.025 && v > 0.62 && v < 0.92 ||
                (u - 0.70 - (v - 0.62) * 0.1).abs < 0.025 && v > 0.60 && v < 0.94
        if horse
          return mix([245, 240, 230], [170, 165, 160], (v - 0.35) * 1.5)
        end
        return [80, 65, 55] if ellipse(u, v, 0.74, 0.60, 0.05, 0.10) < 1 && u > 0.66 # tail
        # rocks at the bottom
        return jitter(mix([90, 80, 65], [50, 45, 40], (v - 0.85) * 5), u, v, 12) if v > 0.88 - 0.05 * Math.sin(u * 4)
        # mountains and dark stormy sky
        return mix([110, 105, 100], [70, 70, 75], vnoise(u, v, 8)) if v > 0.70 - 0.25 * u.clamp(0, 1) * (u < 0.5 ? 1 : -1) + 0.0 && v > 0.55
        sky = mix([60, 55, 55], [140, 130, 115], vnoise(u, v, 4) * 0.8 + (1 - v) * 0.2)
        jitter(sky, u, v, 10, 10)
      end

      # Gainsborough, The Blue Boy
      def the_blue_boy(u, v)
        blue = lambda do
          sheen = Math.sin(u * 50 + v * 20 + vnoise(u, v, 10) * 6)
          mix([40, 80, 140], [160, 200, 230], sheen * 0.5 + 0.5)
        end
        # head and hair
        return [230, 200, 175] if ellipse(u, v, 0.50, 0.18, 0.045, 0.045) < 1
        return [110, 75, 45] if ellipse(u, v, 0.50, 0.17, 0.065, 0.06) < 1
        # lace collar
        return [240, 238, 230] if ellipse(u, v, 0.50, 0.245, 0.07, 0.025) < 1
        # the blue satin suit
        return blue.call if inside?(u, v, [[0.42, 0.25], [0.58, 0.25], [0.63, 0.40], [0.62, 0.62], [0.38, 0.62], [0.37, 0.40]])
        # cape on his left side (viewer's right) and the arm on the hip
        return Color.scale(blue.call, 0.75) if inside?(u, v, [[0.58, 0.25], [0.68, 0.32], [0.70, 0.56], [0.62, 0.55]])
        # the hat in his hand at the viewer's left
        return blue.call if (u - 0.36).abs < 0.025 && v > 0.27 && v < 0.50 # arm
        return [45, 35, 30] if ellipse(u, v, 0.33, 0.55, 0.05, 0.035) < 1
        # legs in blue stockings and shoes
        if v >= 0.62 && v < 0.90
          return blue.call if (u - 0.45).abs < 0.03 || (u - 0.555).abs < 0.03
        end
        return [70, 55, 45] if v >= 0.90 && v < 0.93 && ((u - 0.45).abs < 0.04 || (u - 0.56).abs < 0.04)
        # brownish landscape and cloudy sky
        ground = 0.75 + 0.05 * Math.sin(u * 5)
        return jitter(mix([95, 75, 50], [55, 45, 30], (v - ground) * 3), u, v, 12) if v > ground
        return jitter(mix([60, 60, 45], [100, 90, 65], vnoise(u, v, 10)), u, v, 10) if v > 0.55 + 0.1 * Math.sin(u * 4) || u < 0.2 && v > 0.3
        sky = mix([90, 110, 125], [180, 175, 155], vnoise(u, v, 5) + v * 0.3)
        jitter(sky, u, v, 10, 10)
      end

      # Millais, Ophelia
      def ophelia(u, v)
        # Ophelia floating on her back, face upward at left, dress spread to the right
        return [240, 220, 205] if ellipse(u, v, 0.33, 0.58, 0.035, 0.035) < 1 # face
        return [130, 70, 40] if ellipse(u, v, 0.30, 0.58, 0.07, 0.05) < 1 # auburn hair in the water
        return [235, 215, 200] if ellipse(u, v, 0.40, 0.51, 0.015, 0.02) < 1 || ellipse(u, v, 0.43, 0.66, 0.015, 0.02) < 1 # open hands
        dress = ellipse(u, v, 0.55, 0.59, 0.17, 0.07)
        if dress < 1
          sheen = Math.sin(u * 60 + v * 30) > 0.3
          return sheen ? [200, 200, 185] : [150, 155, 140]
        end
        # scattered flowers on the water
        [[0.47, 0.46, [200, 40, 40]], [0.62, 0.70, [230, 220, 120]], [0.75, 0.52, [210, 90, 150]], [0.25, 0.67, [220, 230, 240]], [0.82, 0.66, [200, 40, 40]]].each do |fx, fy, col|
          return col if dist(u, v, fx, fy, 1.4) < 0.018
        end
        # the dark stream
        bank_top = 0.40 + 0.05 * Math.sin(u * 7)
        bank_bot = 0.80 - 0.04 * Math.sin(u * 5 + 1)
        if v > bank_top && v < bank_bot
          return mix([25, 40, 30], [55, 75, 55], vnoise(u, v, 12) * 0.8)
        end
        # dense green riverbank vegetation
        leaf = vnoise(u, v, 18) * 0.6 + vnoise(u, v, 6) * 0.4
        g = mix([25, 50, 20], [130, 160, 60], leaf * leaf * 1.5)
        return [200, 60, 60] if v < bank_top && noise((u * 60).floor, (v * 40).floor) > 0.988
        return [225, 225, 205] if noise((u * 60).floor + 7, (v * 40).floor) > 0.985
        g
      end

      # Waterhouse, The Lady of Shalott
      def the_lady_of_shalott(u, v)
        # the lady in white, sitting upright with red hair
        return [235, 205, 185] if ellipse(u, v, 0.40, 0.37, 0.025, 0.035) < 1
        return [190, 90, 40] if ellipse(u, v, 0.41, 0.40, 0.04, 0.08) < 1 && u > 0.40
        return [190, 90, 40] if ellipse(u, v, 0.40, 0.35, 0.035, 0.035) < 1
        return jitter([235, 235, 225], u, v, 10) if inside?(u, v, [[0.37, 0.40], [0.45, 0.40], [0.50, 0.62], [0.33, 0.62]])
        # candles and lantern at the prow (left)
        [0.14, 0.17, 0.20].each do |cx|
          return [255, 220, 120] if (u - cx).abs < 0.006 && v > 0.53 && v < 0.55
          return [230, 225, 200] if (u - cx).abs < 0.006 && v > 0.55 && v < 0.61
        end
        return [80, 60, 30] if (u - 0.10).abs < 0.006 && v > 0.40 && v < 0.62
        return [240, 180, 70] if ellipse(u, v, 0.10, 0.42, 0.015, 0.02) < 1
        # the wooden boat with a patterned tapestry draped over the side
        if inside?(u, v, [[0.06, 0.60], [0.85, 0.62], [0.80, 0.70], [0.12, 0.70]])
          if u > 0.25 && u < 0.62
            pat = (u * 40).floor.even? ^ (v * 40).floor.even?
            return pat ? [150, 50, 40] : [190, 150, 70]
          end
          return [90, 60, 35]
        end
        return [150, 50, 40] if u > 0.28 && u < 0.58 && v > 0.70 && v < 0.78 && ((u * 40).floor.even? ^ (v * 40).floor.even?) # tapestry trailing in water
        # reeds in the foreground
        if v > 0.62 && (u < 0.10 || u > 0.88)
          return [110, 115, 60] if Math.sin(u * 140) > 0.2
        end
        # dark water
        if v > 0.58
          refl = Math.sin(v * 100 + Math.sin(u * 13) * 2) > 0.7
          return refl ? [70, 85, 85] : [25, 35, 35]
        end
        # far bank and autumn trees
        return mix([70, 80, 40], [100, 110, 50], vnoise(u, v, 20)) if v > 0.48
        leaf = vnoise(u, v, 10)
        return mix([110, 90, 40], [190, 140, 60], leaf) if v > 0.12 + 0.05 * Math.sin(u * 9) || leaf > 0.6
        jitter([175, 185, 180], u, v, 8)
      end

      # Leutze, Washington Crossing the Delaware
      def washington_crossing_the_delaware(u, v)
        # the flag held up behind Washington, slanting back
        if inside?(u, v, [[0.53, 0.10], [0.68, 0.15], [0.66, 0.38], [0.55, 0.34]])
          return [40, 50, 115] if u < 0.585 && v < 0.21
          return ((v * 32).floor.even? ? [200, 40, 45] : [240, 235, 225])
        end
        return [70, 55, 40] if (u - 0.53 - (v - 0.10) * 0.15).abs < 0.007 && v > 0.08 && v < 0.62
        # Washington standing at the bow
        return [40, 35, 30] if ellipse(u, v, 0.42, 0.175, 0.032, 0.016) < 1 # tricorn hat
        return [225, 195, 165] if ellipse(u, v, 0.42, 0.215, 0.018, 0.032) < 1
        return [75, 70, 85] if inside?(u, v, [[0.39, 0.25], [0.46, 0.25], [0.48, 0.40], [0.46, 0.58], [0.38, 0.58], [0.37, 0.40]])
        return [230, 215, 180] if inside?(u, v, [[0.40, 0.42], [0.45, 0.42], [0.45, 0.58], [0.40, 0.58]]) # breeches
        # the men rowing, crowded into the boat
        [0.18, 0.25, 0.32, 0.51, 0.58, 0.65, 0.72].each_with_index do |mx, i|
          top = 0.42 + (i.even? ? 0.03 : 0.0)
          return [150, 45, 40] if i == 2 && ellipse(u, v, mx, top + 0.07, 0.03, 0.07) < 1
          return [200, 170, 140] if ellipse(u, v, mx, top - 0.01, 0.015, 0.025) < 1
          return [35, 35, 40] if ellipse(u, v, mx, top - 0.035, 0.022, 0.012) < 1
          return [60, 55, 55] if ellipse(u, v, mx, top + 0.09, 0.03, 0.10) < 1
        end
        # oars and poles
        return [90, 70, 45] if (v - 0.60 - (u - 0.12) * 0.6).abs < 0.008 && u > 0.08 && u < 0.24
        return [90, 70, 45] if (v - 0.64 + (u - 0.82) * 0.6).abs < 0.008 && u > 0.76 && u < 0.88
        # the boat
        return [65, 48, 35] if inside?(u, v, [[0.10, 0.58], [0.82, 0.57], [0.78, 0.70], [0.16, 0.70]])
        # ice floes on the river
        if v > 0.54
          f = vnoise(u * 1.5, v * 3, 7)
          return mix([230, 235, 240], [185, 195, 205], (v - 0.54) * 2) if f > 0.6
          return mix([75, 90, 105], [40, 55, 70], (v - 0.54) * 2)
        end
        # far shore with other boats
        return [45, 50, 55] if v > 0.51 - 0.01 * Math.sin(u * 20)
        return [55, 55, 60] if v > 0.47 && (u - 0.88).abs < 0.06 && v > 0.49 - (0.06 - (u - 0.88).abs) * 0.3
        # dawn sky
        sky = ramp(v / 0.52, [80, 90, 110], [150, 150, 150], [250, 225, 160])
        c = vnoise(u, v, 6)
        sky = mix(sky, [60, 65, 80], (c - 0.55) * 1.8) if c > 0.55 && v < 0.35
        jitter(sky, u, v, 6, 10)
      end
    end

    piece(:wanderer_above_the_sea_of_fog, "Wanderer above the Sea of Fog", "Caspar David Friedrich", "c. 1818", aspect: 0.79) { |u, v| wanderer_above_the_sea_of_fog(u, v) }
    piece(:monk_by_the_sea, "The Monk by the Sea", "Caspar David Friedrich", "c. 1810", aspect: 1.56) { |u, v| monk_by_the_sea(u, v) }
    piece(:sea_of_ice, "The Sea of Ice", "Caspar David Friedrich", "1824", aspect: 1.31) { |u, v| sea_of_ice(u, v) }
    piece(:fighting_temeraire, "The Fighting Temeraire", "J. M. W. Turner", "1839", aspect: 1.33) { |u, v| fighting_temeraire(u, v) }
    piece(:rain_steam_and_speed, "Rain, Steam and Speed", "J. M. W. Turner", "1844", aspect: 1.34) { |u, v| rain_steam_and_speed(u, v) }
    piece(:hay_wain, "The Hay Wain", "John Constable", "1821", aspect: 1.42) { |u, v| hay_wain(u, v) }
    piece(:liberty_leading_the_people, "Liberty Leading the People", "Eugène Delacroix", "1830", aspect: 1.25) { |u, v| liberty_leading_the_people(u, v) }
    piece(:raft_of_the_medusa, "The Raft of the Medusa", "Théodore Géricault", "1819", aspect: 1.46) { |u, v| raft_of_the_medusa(u, v) }
    piece(:third_of_may, "The Third of May 1808", "Francisco Goya", "1814", aspect: 1.30) { |u, v| third_of_may(u, v) }
    piece(:the_gleaners, "The Gleaners", "Jean-François Millet", "1857", aspect: 1.33) { |u, v| the_gleaners(u, v) }
    piece(:the_angelus, "The Angelus", "Jean-François Millet", "1859", aspect: 1.19) { |u, v| the_angelus(u, v) }
    piece(:whistlers_mother, "Whistler's Mother", "James McNeill Whistler", "1871", aspect: 1.13) { |u, v| whistlers_mother(u, v) }
    piece(:ninth_wave, "The Ninth Wave", "Ivan Aivazovsky", "1850", aspect: 1.50) { |u, v| ninth_wave(u, v) }
    piece(:the_swing, "The Swing", "Jean-Honoré Fragonard", "1767", aspect: 0.79) { |u, v| the_swing(u, v) }
    piece(:napoleon_crossing_the_alps, "Napoleon Crossing the Alps", "Jacques-Louis David", "1801", aspect: 0.85) { |u, v| napoleon_crossing_the_alps(u, v) }
    piece(:the_blue_boy, "The Blue Boy", "Thomas Gainsborough", "c. 1770", aspect: 0.68) { |u, v| the_blue_boy(u, v) }
    piece(:ophelia, "Ophelia", "John Everett Millais", "1852", aspect: 1.47) { |u, v| ophelia(u, v) }
    piece(:the_lady_of_shalott, "The Lady of Shalott", "John William Waterhouse", "1888", aspect: 1.31) { |u, v| the_lady_of_shalott(u, v) }
    piece(:washington_crossing_the_delaware, "Washington Crossing the Delaware", "Emanuel Leutze", "1851", aspect: 1.71) { |u, v| washington_crossing_the_delaware(u, v) }
  end
end
