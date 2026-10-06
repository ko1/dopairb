# frozen_string_literal: true

require_relative "helper"

class TestConfig < Test::Unit::TestCase
  def test_defaults
    c = Dopairb::Config.new
    assert_equal :max, c.intensity
    assert_equal :soft, c.flash, "full-screen flashing stays opt-in"
    assert_equal :sfx, c.sound
    assert_equal 1.0, c.duration
  end

  def test_apply_string
    c = Dopairb::Config.new.apply_string("intensity=max, flash=off,sound=on duration=0.5 color=256")
    assert_equal :max, c.intensity
    assert_equal :off, c.flash
    assert_equal :sfx, c.sound
    assert_equal 0.5, c.duration
    assert_equal :"256", c.color
  end

  def test_flash_accepts_booleans
    c = Dopairb::Config.new
    c.set(:flash, "on")
    assert_equal :soft, c.flash
    c.set("flash", "full")
    assert_equal :full, c.flash
  end

  def test_errors
    c = Dopairb::Config.new
    assert_raise(ArgumentError) { c.set(:intensity, "loud") }
    assert_raise(ArgumentError) { c.set(:bogus, "1") }
    assert_raise(ArgumentError) { c.set(:duration, "99") }
    assert_raise(ArgumentError) { c.set(:charge, "1") }
    assert_raise(ArgumentError) { c.apply_string("intensity") }
  end

  def test_describe_lists_every_setting
    d = Dopairb::Config.new.describe
    Dopairb::Config::DESCRIPTIONS.each_key { |k| assert_match(/^\s+#{k}\s/, d) }
  end
end
