# frozen_string_literal: true

require_relative "helper"

class TestRender < Test::Unit::TestCase
  include DopairbTestHelper

  def test_canvas_width_and_escapes
    c = Dopairb::Canvas.new(10, 2)
    c.put(-3, 0, "hello world, this is long", [255, 0, 0])
    c.put(8, 1, "日本", [0, 255, 0])
    c.dot(1, 1, [1, 2, 3])
    %i[truecolor 256 16 none].each do |d|
      c.render(d).each do |line|
        assert_only_sgr(line)
        assert_operator Dopairb::Term.str_width(strip_sgr(line)), :<=, 10
      end
    end
  end

  def test_braille
    c = Dopairb::Canvas.new(1, 1)
    c.dot(0, 0, [255, 255, 255])
    c.dot(1, 3, [255, 255, 255])
    assert_equal "⢁", strip_sgr(c.render(:none)[0])
  end

  def test_no_color_depth_emits_no_color_codes
    c = Dopairb::Canvas.new(5, 1)
    c.put(0, 0, "abc", [200, 10, 10], bg: [10, 10, 200])
    line = c.render(:none)[0]
    assert_not_match(/[34]8;|\e\[3[0-7]|\e\[9[0-7]/, line)
  end

  def test_font_covers_banner_words
    %w[FIRST HIT! COMBO NEW RECORD COMEBACK! FIXED! SYNTAX BREAK UNKNOWN SYMBOL FAILED EVALS HUGE ABILITY CLASS MODULE RESULT DOPA IRB 0123456789 ,.].each do |w|
      w.each_char { |ch| assert Dopairb::Font::GLYPHS.key?(ch) || Dopairb::Font::GLYPHS.key?(ch.upcase), ch }
    end
    bm = Dopairb::Font.bitmap("AB")
    assert_equal 5, bm.size
    assert_equal Dopairb::Font.width("AB"), bm[0].size
  end

  def test_color_conversions
    assert_equal 196, Dopairb::Color.to256([255, 0, 0])
    assert_equal 9, Dopairb::Color.to16([255, 0, 0])
    assert_equal [255, 0, 0], Dopairb::Color.hsv(0)
    assert_equal [0, 0, 0], Dopairb::Color.ramp([[0, 0, 0], [255, 255, 255]], -1)
  end
end
