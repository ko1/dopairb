# frozen_string_literal: true

module Dopairb
  # Shown on the line below the input while an evaluation keeps running:
  # an energetic charge at first, then a calm elapsed-time readout.
  class ChargeLine
    DELAY = 0.25
    CALM_AFTER = 3.0

    attr_reader :owner

    def initialize(config, charge: 0.0)
      @config = config
      @charge = charge
      @q = Thread::Queue.new
      @drawn = false
      @dead = false
      @shown = false
      @owner = nil
    end

    def shown? = @shown

    def start
      @t0 = now
      @thread = Thread.new do
        Thread.current.report_on_exception = false
        @owner = Thread.current
        run
      end
      self
    end

    def stop
      @q << :stop
      @thread&.join(0.5)
      Term::LOCK.synchronize do
        clear
        @dead = true
        Term.overlay = nil if Term.overlay.equal?(self)
      end
    end

    # user output is coming (called under Term::LOCK)
    def yield_to_output
      clear
      @dead = true
      Term.overlay = nil if Term.overlay.equal?(self)
    end

    private

    def run
      return if @q.pop(timeout: DELAY)
      Term::LOCK.synchronize do
        return if @dead || OutputTap.output?
        Term.overlay = self
      end
      depth = Term.depth(@config)
      spin = %w[⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷].map { |g| Term.glyph(g, "|") }
      spin = %w[| / - \\] if spin.uniq.size == 1
      i = 0
      loop do
        el = now - @t0
        Term::LOCK.synchronize do
          return if @dead
          Term.out.write("\r\e[2K#{line(el, i, spin, depth)}\e[0m\r")
          @drawn = true
          @shown = true
        end
        i += 1
        break if @q.pop(timeout: el < CALM_AFTER ? 1 / 15.0 : 0.5)
      end
    end

    def line(el, i, spin, depth)
      cols = Term.cols - 2
      if el < CALM_AFTER || !@config.motion
        k = (el - DELAY) / (CALM_AFTER - DELAY)
        cells = [[cols - 30, 24].min, 4].max
        filled = (cells * k.clamp(0, 1)).round
        bar = +""
        cells.times do |x|
          on = x < filled
          col = on ? Color.ramp(Color::FIRE, 0.5 - 0.4 * ((x - i) % 6) / 6.0) : [60, 60, 70]
          bar << Color.sgr(col, nil, on, depth) << Term.glyph(on ? "⣿" : "⣀", on ? "#" : ".")
        end
        head = Color.sgr(Color.rainbow(el), nil, true, depth)
        "#{head}#{spin[i % spin.size]} CHARGING\e[0m #{bar}\e[0m #{Color.sgr([255, 220, 150], nil, true, depth)}#{format('%.1fs', el)}"[0, cols * 30]
      else
        "#{Color.sgr([110, 130, 170], nil, false, depth)}#{spin[i % spin.size]} running #{clock(el)}  (Ctrl-C to interrupt)"
      end
    end

    def clear
      return unless @drawn
      Term.out.write("\r\e[2K")
      @drawn = false
    end

    def clock(el)
      el < 60 ? format("%.1fs", el) : format("%dm%02ds", el / 60, el % 60)
    end

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
