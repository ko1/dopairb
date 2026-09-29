# frozen_string_literal: true

module Dopairb
  # A temporary block of terminal rows starting at the cursor. `top` rows
  # already on screen (the submitted input) can be taken over and are
  # restored verbatim on close.
  class Stage
    attr_reader :height, :top, :owner

    def initialize(height, top: [])
      @height = height
      @top = top
      @owner = Thread.current
      @open = false
      @closed = false
    end

    def total = @top.size + @height
    def open? = @open && !@closed

    def open
      Term::LOCK.synchronize do
        buf = +"\e[?25l\r"
        buf << ("\n" * (@height - 1)) if @height > 1
        up = @height - 1 + @top.size
        buf << "\e[#{up}A" if up > 0
        buf << "\r"
        Term.out.write(buf)
        @open = true
        Term.overlay = self
      end
      self
    end

    def draw(lines)
      Term::LOCK.synchronize do
        return unless open?
        Term.out.write(frame(lines))
      end
    end

    def close
      Term::LOCK.synchronize do
        return unless open?
        restore
        Term.overlay = nil if Term.overlay.equal?(self)
      end
    end

    # Another thread is about to print: get off the screen immediately.
    def yield_to_output
      return unless open?
      restore
      Term.overlay = nil if Term.overlay.equal?(self)
    end

    private

    def restore
      buf = frame(@top + Array.new(@height, ""))
      buf << "\e[#{@top.size}B" if @top.size > 0
      buf << "\r\e[0m\e[?25h"
      Term.out.write(buf)
      @closed = true
    end

    def frame(lines)
      buf = +""
      n = total
      n.times do |i|
        buf << "\r\e[2K" << (lines[i] || "")
        buf << "\e[0m\n" if i < n - 1
      end
      buf << "\e[0m"
      buf << "\e[#{n - 1}A" if n > 1
      buf << "\r"
      buf
    end
  end

  # Full-screen stage on the alternate screen: scrollback is left untouched.
  class AltStage
    attr_reader :height, :owner

    def initialize(height)
      @height = height
      @owner = Thread.current
      @open = false
    end

    def top = []
    def open? = @open

    def open
      Term::LOCK.synchronize do
        Term.out.write("\e[?1049h\e[?25l\e[H\e[2J")
        @open = true
        Term.overlay = self
      end
      self
    end

    def draw(lines)
      Term::LOCK.synchronize do
        return unless @open
        buf = +""
        lines.each_with_index { |l, i| buf << "\e[#{i + 1};1H\e[2K" << l << "\e[0m" }
        Term.out.write(buf)
      end
    end

    def close
      Term::LOCK.synchronize { restore }
    end

    def yield_to_output
      restore
    end

    private

    def restore
      return unless @open
      Term.out.write("\e[0m\e[?1049l\e[?25h")
      @open = false
      Term.overlay = nil if Term.overlay.equal?(self)
    end
  end
end
