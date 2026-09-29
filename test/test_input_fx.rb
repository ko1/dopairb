# frozen_string_literal: true

require_relative "helper"

class TestInputFx < Test::Unit::TestCase
  include DopairbTestHelper

  def setup
    @clock, @tick = fake_clock
    @cfg = Dopairb::Config.new
    @game = Dopairb::Game.new(clock: @clock)
    @fx = Dopairb::InputFx.new(@cfg, @game, clock: @clock, rng: Random.new(3))
    @lines = [+""]
    @bp = 0
  end

  def lay(x = 20 + @bp)
    Dopairb::InputFx::Layout.new(cursor_x: x, cursor_row: 0, row_end_x: 20 + @lines[0].size, last_row: 0,
                                 screen_width: 80, room_below: 5)
  end

  def type(str, sym: :ed_insert)
    str.each_char do |ch|
      before = [@lines.map(&:dup), 0, @bp]
      @lines[0] = @lines[0].byteslice(0, @bp) + ch + @lines[0].byteslice(@bp..)
      @bp += ch.bytesize
      @fx.on_key(sym, before, [@lines.map(&:dup), 0, @bp], prev_x: 20 + @bp - 1, cur_x: 20 + @bp)
      @tick.(0.05)
    end
  end

  def backspace
    before = [@lines.map(&:dup), 0, @bp]
    @lines[0] = @lines[0].byteslice(0, @bp - 1) + @lines[0].byteslice(@bp..)
    @bp -= 1
    @fx.on_key(:em_delete_prev_char, before, [@lines.map(&:dup), 0, @bp], prev_x: 21 + @bp, cur_x: 20 + @bp)
  end

  def colored = "\e[1;34m#{@lines[0]}\e[0m\n"
  def raw = "#{@lines[0]}\n"

  def test_insert_sparks_and_trail
    type("abc")
    assert @fx.animating?
    x, rows = @fx.trail_render(lay)
    assert_equal 24, x
    assert_only_sgr(rows[0])
    assert_not_nil @fx.strip_render(lay)
    @tick.(2)
    assert_nil @fx.strip_render(lay)
    assert_nil @fx.trail_render(lay)
  end

  def test_highlights_keep_text
    type("foo(1, [2])")
    out = @fx.apply(colored, raw)
    assert_not_equal colored, out, "closing a bracket highlights the pair"
    assert_equal raw, strip_sgr(out)
    @tick.(3)
    assert_equal colored, @fx.apply(colored, raw), "highlights expire"
  end

  def test_bracket_pair_detection_uses_the_right_opener
    type("[(1)")
    ranges = @fx.instance_variable_get(:@highlights).select { |h| h.kind == :pair }.map { |h| [h.from, h.to] }
    assert_include ranges, [1, 2]
    assert_include ranges, [3, 4]
  end

  def test_mismatched_bracket_is_ignored
    type("[1)")
    assert_empty @fx.instance_variable_get(:@highlights).select { |h| h.kind == :pair }
  end

  def test_string_and_block_close
    type('x = "hi"')
    assert @fx.instance_variable_get(:@highlights).any? { |h| h.kind == :range && h.from == 4 && h.to == 8 }
    @lines = ["[1].each do |x|", "  x", "en"]
    before = [@lines.map(&:dup), 2, 2]
    @lines[2] = "end"
    @fx.on_key(:ed_insert, before, [@lines.map(&:dup), 2, 3], prev_x: 2, cur_x: 3)
    assert @fx.instance_variable_get(:@highlights).any? { |h| h.kind == :range && h.from == 4 }
  end

  def test_endless_def_does_not_confuse_block_matching
    @lines = ["def f = 1; begin", "en"]
    before = [@lines.map(&:dup), 1, 2]
    @lines[1] = "end"
    @fx.on_key(:ed_insert, before, [@lines.map(&:dup), 1, 3], prev_x: 2, cur_x: 3)
    hl = @fx.instance_variable_get(:@highlights).find { |h| h.kind == :range }
    assert_equal 11, hl.from
  end

  def test_delete_then_recovery
    type("ab")
    backspace
    assert_not_nil @fx.strip_render(lay)
    type("c")
    pop = @fx.instance_variable_get(:@popups).last
    assert_equal "RECOVERY", pop.text
  end

  def test_paste_is_one_event
    before = [[+""], 0, 0]
    50.times do |i|
      @fx.on_key(:ed_insert, before, [["x" * (i + 1)], 0, i + 1], prev_x: 0, cur_x: i, pasting: true)
    end
    assert_empty @fx.instance_variable_get(:@parts).list
    @fx.on_key(:ed_insert, [["x" * 50], 0, 50], [["x" * 51], 0, 51], prev_x: 70, cur_x: 71)
    assert @fx.instance_variable_get(:@popups).any? { |p| p.text == "PASTE x50" }
  end

  def test_history_and_completion
    @fx.on_key(:ed_prev_history, [[""], 0, 0], [["1 + 1"], 0, 5], prev_x: 20, cur_x: 25)
    assert @fx.instance_variable_get(:@highlights).any? { |h| h.kind == :reveal }
    @fx.on_key(:complete, [["[].ma"], 0, 5], [["[].map"], 0, 6], prev_x: 25, cur_x: 26)
    x, = @fx.trail_render(Dopairb::InputFx::Layout.new(cursor_x: 26, cursor_row: 0, row_end_x: 26, last_row: 0, screen_width: 80, room_below: 5))
    assert_equal 27, x
  end

  def test_hud_fits_or_hides
    type("a")
    x, rows = @fx.hud_render(lay)
    assert_operator x, :>, lay.row_end_x
    assert_operator x + Dopairb::Term.str_width(strip_sgr(rows[0])), :<, 80
    narrow = Dopairb::InputFx::Layout.new(cursor_x: 30, cursor_row: 0, row_end_x: 30, last_row: 0, screen_width: 36, room_below: 5)
    assert_nil @fx.hud_render(narrow)
    @cfg.set(:hud, false)
    assert_nil @fx.hud_render(lay)
  end

  def test_keys_off_means_no_effects
    @cfg.set(:keys, false)
    type("foo()")
    assert_nil @fx.trail_render(lay)
    assert_nil @fx.strip_render(lay)
    assert_equal colored, @fx.apply(colored, raw)
  end

  def test_multibyte_input
    type("あい(う)")
    out = @fx.apply(colored, raw)
    assert_equal raw, strip_sgr(out)
  end
end
