# frozen_string_literal: true

require "io/console"
require "io/wait"

module Dopairb
  # Terminal capabilities and the single writer lock shared by everything
  # that draws transient decorations.
  module Term
    LOCK = Monitor.new

    class << self
      attr_writer :out, :input
      # The transient thing on screen that must get out of the way when the
      # user's program writes (a Stage or the ChargeLine). Guarded by LOCK.
      attr_accessor :overlay

      def out
        @out ||= begin
          io = IO.for_fd(STDOUT.fileno, autoclose: false)
          io.sync = true
          io
        end
      end

      def input
        @input || STDIN
      end

      def interactive?
        return @interactive unless @interactive.nil?
        @interactive = STDIN.tty? && STDOUT.tty? && ENV["TERM"] != "dumb"
      end

      def interactive=(v)
        @interactive = v
      end

      def size
        rows, cols = (input.winsize rescue [0, 0])
        rows = (ENV["LINES"] || 24).to_i if rows.to_i <= 0
        cols = (ENV["COLUMNS"] || 80).to_i if cols.to_i <= 0
        [rows, cols]
      end

      def rows = size[0]
      def cols = size[1]

      def depth(config)
        return :none if no_color? || config.color == :none
        return config.color unless config.color == :auto
        ct = ENV["COLORTERM"].to_s
        return :truecolor if ct.include?("truecolor") || ct.include?("24bit")
        return :"256" if ENV["TERM"].to_s.include?("256")
        :"16"
      end

      def no_color?
        nc = ENV["NO_COLOR"]
        !(nc.nil? || nc.empty?)
      end

      def write(str)
        LOCK.synchronize { out.write(str) }
      rescue IOError, SystemCallError
        nil
      end

      def char_width(ch)
        if defined?(Reline::Unicode)
          Reline::Unicode.get_mbchar_width(ch)
        else
          ch.ord < 0x1100 ? 1 : 2
        end
      rescue StandardError
        1
      end

      def str_width(str)
        if defined?(Reline::Unicode)
          Reline::Unicode.calculate_width(str, true)
        else
          str.gsub(/\e\[[\d;]*[A-Za-z]/, "").each_char.sum { |c| char_width(c) }
        end
      end

      # First candidate that renders one column wide on this terminal.
      # A nil candidate means "none of the above": glyph("▀", nil) may be nil.
      def glyph(*candidates)
        @glyphs ||= {}
        return @glyphs[candidates] if @glyphs.key?(candidates)
        @glyphs[candidates] = candidates.find { |c| c.nil? || c.ascii_only? || (utf8? && c.each_char.all? { |ch| char_width(ch) == 1 }) } || candidates.last
      end

      def reset_glyphs
        @glyphs = nil
      end

      def utf8?
        return @utf8 unless @utf8.nil?
        @utf8 = Encoding.default_external == Encoding::UTF_8 || ENV.values_at("LC_ALL", "LC_CTYPE", "LANG").compact.any? { |v| v =~ /utf-?8/i }
      end

      # Keys typed during an effect cut it short; they stay queued for Reline.
      def input_pending?
        if defined?(Reline::IOGate) && Reline::IOGate.respond_to?(:empty_buffer?)
          return true unless Reline::IOGate.empty_buffer?
        end
        input.wait_readable(0) ? true : false
      rescue StandardError
        false
      end

      def raw
        return yield unless input.tty?
        input.raw(intr: true) { yield }
      rescue Errno::ENOTTY, Errno::EINVAL
        yield
      end

      def bell
        write("\a")
      end

      # Called (under LOCK) by the output tap before user output hits the terminal.
      def yield_to_output
        ov = overlay
        return if ov.nil? || ov.owner == Thread.current
        ov.yield_to_output
      end
    end
  end
end
