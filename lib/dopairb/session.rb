# frozen_string_literal: true

module Dopairb
  # One interactive session: owns the game state and ties the evaluation
  # cycle to the director.
  class Session
    attr_reader :config, :game, :director, :fx
    attr_accessor :cold_start

    def initialize(config)
      @config = config
      @game = Game.new
      @director = Director.new(config)
      @fx = InputFx.new(config, @game)
      @finished = false
    end

    def active?
      !@config.off? && Term.interactive?
    end

    def intro
      return unless active?
      Sound.warm_up(@config.duration)
      cold = @cold_start || (Sound.available? && !Sound.ready?(:intro, @config.duration))
      if @config.intro && @config.motion && cold
        @director.loading { Sound.ready?(:intro, @config.duration) }
      end
      @director.intro
    end

    def finish
      return if @finished
      @finished = true
      @director.outro(@game.stats) if active? && @game.evals > 0
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
        event = @game.success(info, code: code, out_lines: lines)
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

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
