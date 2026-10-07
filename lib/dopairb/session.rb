# frozen_string_literal: true

module Dopairb
  # One interactive session: owns the game state and ties the evaluation
  # cycle to the director.
  class Session
    attr_reader :config, :game, :director, :fx, :collected
    attr_accessor :cold_start
    # Hooked into IRB but not playing: `require "dopairb"` without enable.
    attr_accessor :dormant

    def initialize(config)
      @config = config
      # DOPAIRB_SEED makes the luck (crits, jackpots, sparks) repeatable, e.g. for recordings.
      seed = ENV["DOPAIRB_SEED"]
      @game = seed ? Game.new(rng: Random.new(seed.to_i)) : Game.new
      @director = seed ? Director.new(config, rng: Random.new(seed.to_i + 1)) : Director.new(config)
      @fx = InputFx.new(config, @game)
      @finished = false
      @introduced = false
      @profile = nil
      @collected = []
    end

    # Loaded on first use, and only for interactive sessions.
    def profile
      @profile ||= begin
        prof = active? ? Profile.load : Profile.new
        @start = { xp: prof.xp, level: prof.level, best_score: prof.best_score, sessions: prof.sessions }
        @game.career(xp: prof.xp, best_combo: prof.best_combo.positive? ? prof.best_combo : nil) if prof.persistent?
        prof
      end
    end

    def active?
      !@dormant && !@config.off? && Term.interactive? && (@config.binding_irb || !IrbAdapter.from_binding?)
    end

    # Once per process: from the dopairb command before IRB starts, or for
    # `Dopairb.enable` in .irbrc right before the first prompt -- or, when it
    # starts switched off, before the first prompt after `dopa on`.
    def intro
      return if @introduced || !active?
      @introduced = true
      prof = profile
      grew = prof.visit
      prof.save if grew
      Sound.warm_up(@config.duration)
      cold = @cold_start || (Sound.available? && !Sound.ready?(:intro, @config.duration))
      if @config.intro && @config.motion && cold
        @director.loading { Sound.ready?(:intro, @config.duration) }
      end
      @director.intro(prof.persistent? ? { level: prof.level, streak: prof.streak, streak_up: grew && prof.streak >= 2 } : nil)
    end

    def finish
      return if @finished
      @finished = true
      return unless active? && @game.evals > 0
      prof = profile
      stats = @game.stats
      if prof.persistent?
        stats = stats.merge(xp_before: @start[:xp], level_before: @start[:level], level: @game.level, xp: @game.xp,
                            best_before: @start[:best_score], first_session: @start[:sessions].zero?)
      end
      prof.visit
      @profile = prof.finish(stats, collected: @collected)
      @director.outro(stats.merge(gallery: @profile.gallery.size, gallery_total: Gallery::PIECES.size))
    end

    def around_eval(code, last_value)
      input = RelineAdapter.take_input(code)
      OutputTap.start
      charge = @config.motion ? ChargeLine.new(@config, charge: @game.charge).start : nil
      t0 = now
      completed = false
      failure = nil
      begin
        result = yield
        completed = true
        result
      rescue Exception => e # rubocop:disable Lint/RescueException
        failure = e
        raise
      ensure
        charge&.stop
        lines, = OutputTap.stop
        # a throw (e.g. irb_exit) leaves neither flag set: stay quiet
        if completed
          react(:success, code, last_value, input, lines, now - t0, charge)
        elsif failure && !(SystemExit === failure)
          react(failure, code, last_value, input, lines, now - t0, charge)
        end
      end
    end

    private

    def react(outcome, code, last_value, input, lines, elapsed, charge)
      clean = !OutputTap.output?
      shot = clean ? input : nil
      if outcome == :success
        info = Probe.value(last_value.call, code).merge(out_lines: lines)
        profile
        event = @game.success(info, code: code, out_lines: lines)
        award_art(event) if %i[level_up jackpot art_drop].any? { |f| event.flag?(f) } && @game.leveling?
        pre = elapsed > 0.2 || shot.nil? ? 0.0 : [@config.charge, 0.3].min
        @director.play_event(event, input: shot, pre: pre)
      else
        info = Probe.exception(outcome, code)
        event = info[:type] == :interrupt ? @game.interrupted : @game.failure(info)
        @director.play_event(event, input: shot)
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      raise if SystemExit === e
      Dopairb.debug(e)
    end

    # Level-ups, jackpots and lucky drops pay out a masterpiece, a new one while any are missing.
    def award_art(event)
      owned = profile.gallery + @collected
      piece = Gallery.pick(@director.rng, owned)
      fresh = !owned.include?(piece.id)
      @collected << piece.id if fresh
      event.info[:art] = piece.id
      event.info[:art_new] = fresh
      event.info[:gallery] = [(owned + [piece.id]).uniq.size, Gallery::PIECES.size]
    end

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
