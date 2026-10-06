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
    bonus = Dopairb::Game::TYPING_MILESTONES.sum { |n| n * 4 }
    assert_operator @g.score, :<=, 200 + bonus, "the cap plus each power-of-two streak once"
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

  # rand always answers r (and sample picks by it too)
  def fixed_rng(r)
    Object.new.tap { |o| o.define_singleton_method(:rand) { |n = nil| n ? (r * n).floor : r } }
  end

  def test_critical_and_jackpot
    crit = Dopairb::Game.new(clock: @clock, rng: fixed_rng(0.05))
    e = crit.success(int(1))
    assert e.flag?(:critical)
    assert_includes Dopairb::Game::CRIT_MULTS, e.mult
    plain = Dopairb::Game.new(clock: @clock, rng: fixed_rng(0.99)).success(int(1))
    assert_equal plain.gain * e.mult, e.gain
    jp = Dopairb::Game.new(clock: @clock, rng: fixed_rng(0.001)).success(int(1))
    assert jp.flag?(:jackpot)
    assert_equal plain.gain * Dopairb::Game::JACKPOT_MULT, jp.gain
  end

  def test_fever_doubles_and_ends_on_error
    g = Dopairb::Game.new(clock: @clock, rng: fixed_rng(0.99))
    evs = 11.times.map { g.success(int(1)) }
    assert evs[9].flag?(:fever_start)
    assert evs[10].flag?(:fever)
    assert !evs[8].flag?(:fever)
    assert_equal 2, evs[10].mult
    assert g.failure({ type: :name }).flag?(:fever_end)
    assert !g.fever?
  end

  def test_levels_double
    assert_equal 1, Dopairb::Game.level_for(511)
    assert_equal 2, Dopairb::Game.level_for(512)
    assert_equal 3, Dopairb::Game.level_for(1024)
    assert_equal 4, Dopairb::Game.level_for(2048)
  end

  def test_level_up_only_with_a_career
    g = Dopairb::Game.new(clock: @clock, rng: fixed_rng(0.99))
    assert 20.times.none? { g.success(int(1)).flag?(:level_up) }
    g = Dopairb::Game.new(clock: @clock, rng: fixed_rng(0.99))
    g.career(xp: 500, best_combo: nil)
    e = g.success(int(1))
    assert e.flag?(:level_up)
    assert_equal 2, e.level
  end

  def test_best_combo_ever
    g = Dopairb::Game.new(clock: @clock, rng: fixed_rng(0.99))
    g.career(xp: 0, best_combo: 6)
    evs = 8.times.map { g.success(int(1)) }
    assert_equal [6], evs.each_index.select { |i| evs[i].flag?(:combo_best) }
  end

  def test_power_of_two_typing_streaks
    hits = []
    40.times do |i|
      r = @g.key(:insert, (97 + i % 26).chr)
      hits << r[1] if Array === r
      @tick.(0.05)
    end
    assert_equal [8, 16, 32], hits
  end
end
