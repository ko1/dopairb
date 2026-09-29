# frozen_string_literal: true

module Dopairb
  # COMBO / CHARGE / SCORE bookkeeping. Points are toys: they reward rhythm
  # and recovery, never code length or correctness.
  class Game
    CHARGE_MAX = 100.0
    TYPING_WINDOW = 0.6
    COMBO_MILESTONES = [3, 5, 10, 15, 20, 30, 50, 75, 100].freeze
    COMBO_MEGA = [10, 25, 50, 100].freeze
    EVAL_MILESTONES = [10, 50, 100, 500, 1000, 5000, 10_000].freeze

    Event = Struct.new(:kind, :tier, :info, :flags, :gain, :combo, :streak, :score, keyword_init: true) do
      def flag?(f) = flags.include?(f)
    end

    attr_reader :score, :combo, :max_combo, :evals, :successes, :failures, :interrupts,
                :charge, :error_streak, :record, :typing_combo, :started_at, :last_key_at,
                :keystrokes, :best_typing

    def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @clock = clock
      @started_at = now
      @score = 0
      @combo = 0
      @max_combo = 0
      @evals = 0
      @successes = 0
      @failures = 0
      @interrupts = 0
      @charge = 0.0
      @error_streak = 0
      @record = nil
      @typing_combo = 0
      @best_typing = 0
      @last_key_at = nil
      @last_char = nil
      @same_char = 0
      @typing_points = 0
      @keystrokes = 0
    end

    def now = @clock.call

    def multiplier(t = nil)
      return 1.0 if t && (@last_key_at.nil? || t - @last_key_at > TYPING_WINDOW * 2)
      1.0 + [@typing_combo, 50].min / 25.0
    end

    def heat(t = now)
      return 0.0 unless @last_key_at
      idle = t - @last_key_at
      base = [@charge / CHARGE_MAX, @typing_combo / 30.0].max.clamp(0.0, 1.0)
      base * Math.exp(-[idle - 1.0, 0].max / 4.0)
    end

    # kind: :insert, :delete, :move, :bracket, :string, :block, :complete, :history, :newline, :paste
    # Returns :resume when typing restarts after a pause, else nil.
    def key(kind, char = nil)
      t = now
      resumed = @last_key_at && t - @last_key_at > 2.0 && kind == :insert
      if @last_key_at && t - @last_key_at <= TYPING_WINDOW
        @typing_combo += 1 unless kind == :move
      else
        @typing_combo = kind == :move ? 0 : 1
      end
      @best_typing = @typing_combo if @typing_combo > @best_typing
      @last_key_at = t
      @keystrokes += 1 unless kind == :paste

      gain, pts = case kind
                  when :insert then [2.2, 1]
                  when :delete then [0.6, 0]
                  when :move then [0.2, 0]
                  when :bracket then [6.0, 15]
                  when :string then [4.0, 10]
                  when :block then [9.0, 25]
                  when :complete then [5.0, 20]
                  when :history then [3.0, 5]
                  when :newline then [8.0, 10]
                  when :paste then [10.0, 10]
                  else [0.0, 0]
                  end
      if kind == :insert
        if char == @last_char
          @same_char += 1
        else
          @same_char = 0
          @last_char = char
        end
        gain *= 0.35**[@same_char, 4].min
        pts = 0 if @same_char > 2
      end
      @charge += gain * (1 - @charge / CHARGE_MAX)
      @charge = CHARGE_MAX if @charge > CHARGE_MAX
      if @typing_points < 200
        p = (pts * multiplier).round
        @typing_points += p
        @score += p
      end
      resumed ? :resume : nil
    end

    def success(info, code: "", out_lines: 0)
      @evals += 1
      @successes += 1
      flags = []
      flags << :first_hit if @successes == 1
      flags << :comeback if @error_streak > 0
      streak = @error_streak
      @error_streak = 0
      @combo += 1
      @max_combo = @combo if @combo > @max_combo
      flags << :combo_milestone if COMBO_MILESTONES.include?(@combo)
      flags << :combo_mega if COMBO_MEGA.include?(@combo)
      flags << :eval_milestone if EVAL_MILESTONES.include?(@evals)
      flags << :output_rain if out_lines >= 20

      if (num = numeric(info))
        if @record && num > @record && num >= 100
          flags << :new_record
          flags << :record_jump if @record <= 0 ? num >= 1000 : num >= @record * 2
        end
        @record = num if @record.nil? || num > @record
      end

      gain = 100 + [@combo - 1, 40].min * 25 + (@charge * 2).round
      gain += 500 if flags.include?(:comeback)
      gain += 100 if flags.include?(:first_hit)
      gain += 300 if flags.include?(:new_record)
      gain += 1000 if flags.include?(:eval_milestone)
      gain += @combo * 20 if flags.include?(:combo_milestone)
      @score += gain
      @charge = 0.0
      @typing_points = 0

      Event.new(kind: info[:type] == :definition ? :definition : :success, tier: nil, info: info, flags: flags,
                gain: gain, combo: @combo, streak: streak, score: @score)
    end

    def failure(info)
      @evals += 1
      @failures += 1
      @error_streak += 1
      broken = @combo
      @combo = 0
      @charge = 0.0
      @typing_points = 0
      flags = []
      flags << :combo_break if broken >= 3
      flags << :eval_milestone if EVAL_MILESTONES.include?(@evals)
      Event.new(kind: :failure, tier: nil, info: info.merge(broken_combo: broken), flags: flags, gain: 0,
                combo: 0, streak: @error_streak, score: @score)
    end

    def interrupted
      @interrupts += 1
      lost = @charge
      @charge = 0.0
      @typing_points = 0
      Event.new(kind: :interrupt, tier: nil, info: { charge: lost }, flags: [], gain: 0, combo: @combo,
                streak: @error_streak, score: @score)
    end

    def elapsed = now - @started_at

    def stats
      { evals: @evals, successes: @successes, failures: @failures, interrupts: @interrupts,
        max_combo: @max_combo, score: @score, keystrokes: @keystrokes, best_typing: @best_typing,
        time: elapsed }
    end

    private

    def numeric(info)
      case info[:type]
      when :integer then info[:value]
      when :float then info[:value].finite? ? info[:value] : nil
      end
    end
  end
end
