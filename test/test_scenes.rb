# frozen_string_literal: true

require_relative "helper"

# Every scene, at every width and color depth, sampled over its whole length.
class TestScenes < Test::Unit::TestCase
  include DopairbTestHelper

  WIDTHS = [19, 39, 79, 139, 239].freeze
  DEPTHS = %i[truecolor 256 16 none].freeze

  def director(level = :normal)
    cfg = Dopairb::Config.new
    cfg.set(:intensity, level)
    Dopairb::Director.new(cfg, rng: Random.new(1))
  end

  def shot(code, w)
    line = "dopa> #{code}"
    Dopairb::InputShot.new(rows: [line], lines: [[6, code]], code: code, screen_width: w + 1)
  end

  def scenes_for(w, depth, level)
    d = director(level)
    Dopairb::Demo.cases.map do |code, ev|
      ctx = d.ctx(input: shot(code, w), pre: 0.1, rows: 30, cols: w + 1)
      ctx.depth = depth
      d.scene_for(ev, ctx)
    end + [
      Dopairb::Scenes::Intro.new(d.ctx(rows: 30, cols: w + 1).tap { |c| c.depth = depth }),
      Dopairb::Scenes::Outro.new(d.ctx(rows: 30, cols: w + 1).tap { |c| c.depth = depth },
                                 { evals: 12, successes: 10, failures: 2, interrupts: 0, max_combo: 7, score: 12_480, keystrokes: 300, time: 75 }),
    ]
  end

  def check_scene(scene, w)
    top = scene.top? ? scene.ctx.input.size : 0
    t = 0.0
    while t <= scene.total_length + 0.05
      if top > 0
        tc = Dopairb::Canvas.new(w, top)
        tc.render(scene.depth).each { |l| assert_only_sgr(l) } if scene.draw_top(tc, t)
      end
      c = Dopairb::Canvas.new(w, scene.height)
      ts = t - scene.pre
      scene.draw(c, ts) if ts >= 0
      lines = c.render(scene.depth, shake: ts >= 0 ? scene.shake(ts) : 0)
      assert_equal scene.height, lines.size
      lines.each do |l|
        assert_only_sgr(l, "#{scene.class} t=#{t}")
        assert_operator Dopairb::Term.str_width(strip_sgr(l)), :<=, w, "#{scene.class} w=#{w} t=#{t}: #{strip_sgr(l).inspect}"
      end
      t += 0.037
    end
    tr = scene.trail
    tr&.split("\n")&.each { |l| assert_only_sgr(l) }
  end

  WIDTHS.each do |w|
    DEPTHS.each do |depth|
      define_method("test_scenes_w#{w}_#{depth}") do
        scenes_for(w, depth, :normal).each { |s| check_scene(s, w) }
      end
    end
  end

  def test_low_intensity_is_compact
    scenes_for(139, :"256", :low).each do |s|
      check_scene(s, 139)
      assert_operator s.height, :<=, 12, s.class.to_s unless s.is_a?(Dopairb::Scenes::Outro)
    end
  end

  def test_max_intensity_uses_full_screen_for_mega
    d = director(:max)
    _, ev = Dopairb::Demo.cases.find { |_, e| e.flag?(:comeback) }
    s = d.scene_for(ev, d.ctx(rows: 30, cols: 100))
    assert s.mega?
    assert_equal 30, s.height
    check_scene(s, 99)
  end

  def test_priority
    d = director
    ctx = d.ctx(rows: 30, cols: 100)
    ev = Dopairb::Game::Event.new(kind: :success, info: { type: :integer, value: 1 }, flags: %i[first_hit comeback combo_milestone],
                                  gain: 1, combo: 5, streak: 1, score: 0)
    s = d.scene_for(ev, ctx)
    assert_kind_of Dopairb::Scenes::Banner, s
    assert_match(/FIXED/, strip_sgr(s.trail))
  end
end
