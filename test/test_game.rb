# frozen_string_literal: true

require_relative "helper"

class TestGame < Test::Unit::TestCase
  include DopairbTestHelper

  def setup
    @clock, @tick = fake_clock
    @g = Dopairb::Game.new(clock: @clock)
  end

  def int(v) = { type: :integer, value: v }

  def test_combo_and_first_hit
    e = @g.success(int(1))
    assert e.flag?(:first_hit)
    assert_equal 1, @g.combo
    e = @g.success({ type: :nil })
    assert !e.flag?(:first_hit)
    @g.success({ type: :false })
    assert_equal 3, @g.combo, "nil and false keep the combo going"
  end

  def test_failure_breaks_combo_and_comeback
    3.times { @g.success(int(1)) }
    f = @g.failure({ type: :name })
    assert_equal 0, @g.combo
    assert f.flag?(:combo_break)
    @g.failure({ type: :syntax })
    s = @g.success(int(1))
    assert s.flag?(:comeback)
    assert_equal 2, s.streak
    assert !@g.success(int(1)).flag?(:comeback)
  end

  def test_interrupt_keeps_combo
    2.times { @g.success(int(1)) }
    @g.interrupted
    assert_equal 2, @g.combo
    assert_equal 1, @g.interrupts
  end

  def test_new_record
    @g.success(int(50))
    assert !@g.success(int(80)).flag?(:new_record), "below 100 is not a record"
    e = @g.success(int(150))
    assert e.flag?(:new_record)
    assert !e.flag?(:record_jump)
    assert @g.success(int(1000)).flag?(:record_jump)
    assert !@g.success(int(10)).flag?(:new_record)
  end

  def test_charge_is_capped_and_repetition_diminishes
    500.times do |i|
      @g.key(:insert, (97 + i % 26).chr)
      @tick.(0.05)
    end
    assert_operator @g.charge, :<=, Dopairb::Game::CHARGE_MAX
    g2 = Dopairb::Game.new(clock: @clock)
    20.times { g2.key(:insert, "a"); @tick.(0.05) }
    g3 = Dopairb::Game.new(clock: @clock)
    20.times { |i| g3.key(:insert, "abcd"[i % 4]); @tick.(0.05) }
    assert_operator g2.charge, :<, g3.charge / 2
  end

  def test_typing_score_is_capped_per_eval
    2000.times { |i| @g.key(:insert, (97 + i % 26).chr); @tick.(0.01) }
    assert_operator @g.score, :<=, 200
  end

  def test_resume_after_pause
    @g.key(:insert, "a")
    @tick.(3.0)
    assert_equal :resume, @g.key(:insert, "b")
    @tick.(0.1)
    assert_nil @g.key(:insert, "c")
  end

  def test_milestones
    evs = 10.times.map { @g.success(int(1)) }
    assert evs[4].flag?(:combo_milestone)
    assert evs[9].flag?(:combo_mega)
    assert evs[9].flag?(:eval_milestone)
  end

  def test_output_rain_flag
    assert @g.success({ type: :nil }, out_lines: 25).flag?(:output_rain)
    assert !@g.success({ type: :nil }, out_lines: 3).flag?(:output_rain)
  end
end
