# frozen_string_literal: true

require "reline"

# Minimal VT100/xterm screen model: enough of the sequences Reline, IRB and
# dopairb emit to reconstruct what a user would see. Answers DSR (ESC[6n).
class VT
  Cell = Struct.new(:ch, :style)

  attr_reader :rows, :cols, :scrollback, :unknown, :alt, :flashes

  def initialize(rows, cols, reply: nil)
    @rows = rows
    @cols = cols
    @reply = reply
    @main = blank_screen
    @alt_screen = nil
    @scrollback = []
    @y = 0
    @x = 0
    @style = nil
    @saved = [0, 0]
    @buf = +"".b
    @unknown = Hash.new(0)
    @wrap_pending = false
    @alt = false
    @flashes = 0
  end

  def screen = @alt ? @alt_screen : @main
  def cursor = [@y, @x]

  def feed(bytes)
    @buf << bytes.b
    loop do
      break if @buf.empty?
      if @buf.getbyte(0) == 0x1b
        consumed = escape
        break unless consumed
        @buf = @buf.byteslice(consumed..)
      else
        # take a full UTF-8 char
        len = utf8_len(@buf.getbyte(0))
        break if @buf.bytesize < len
        ch = @buf.byteslice(0, len).force_encoding(Encoding::UTF_8)
        @buf = @buf.byteslice(len..)
        char(ch)
      end
    end
  end

  def lines
    screen.map { |row| row.map { |c| c.ch }.join.rstrip }
  end

  def text
    lines.join("\n")
  end

  def all_text
    (@scrollback.map { |row| row.map(&:ch).join.rstrip } + lines).join("\n").sub(/\n+\z/, "")
  end

  def styled_at?(y, x)
    !screen[y][x].style.nil?
  end

  private

  def blank_screen = Array.new(@rows) { blank_row }
  def blank_row = Array.new(@cols) { Cell.new(" ", nil) }

  def utf8_len(b)
    if b < 0x80 then 1
    elsif b >= 0xF0 then 4
    elsif b >= 0xE0 then 3
    elsif b >= 0xC0 then 2
    else 1
    end
  end

  def char(ch)
    case ch
    when "\r" then @x = 0; @wrap_pending = false
    when "\n" then linefeed
    when "\b" then @x -= 1 if @x > 0; @wrap_pending = false
    when "\a" then nil
    when "\t" then @x = [(@x / 8 + 1) * 8, @cols - 1].min
    when "\x00".."\x1f" then @unknown["ctrl-#{ch.ord}"] += 1
    else
      w = Reline::Unicode.get_mbchar_width(ch)
      return if w <= 0
      if @wrap_pending || @x + w > @cols
        @x = 0
        linefeed
        @wrap_pending = false
      end
      screen[@y][@x] = Cell.new(ch, @style)
      screen[@y][@x + 1] = Cell.new("", @style) if w == 2 && @x + 1 < @cols
      @x += w
      if @x >= @cols
        @x = @cols - 1
        @wrap_pending = true
      end
    end
  end

  def linefeed
    @wrap_pending = false
    if @y == @rows - 1
      scroll_up
    else
      @y += 1
    end
  end

  def scroll_up
    row = screen.shift
    @scrollback << row unless @alt
    screen << blank_row
  end

  def escape
    return nil if @buf.bytesize < 2
    c1 = @buf.getbyte(1).chr
    case c1
    when "["
      m = @buf.match(/\A\e\[([?>=]?)([\d;]*)([ -\/]*)([@-~])/n)
      return (@buf.bytesize > 64 ? (@unknown["bad-csi"] += 1; 2) : nil) unless m
      csi(m[1], m[2], m[4])
      m[0].bytesize
    when "]"
      i = @buf.index("\a") || @buf.index("\e\\")
      return nil unless i
      i + (@buf[i] == "\a" ? 1 : 2)
    when "7" then @saved = [@y, @x]; 2
    when "8" then @y, @x = @saved; @wrap_pending = false; 2
    when "D" then linefeed; 2
    when "M"
      if @y == 0
        screen.unshift(blank_row)
        screen.pop
      else
        @y -= 1
      end
      2
    when "=" , ">" then 2
    when "(" , ")" then 3
    else
      @unknown["esc-#{c1}"] += 1
      2
    end
  end

  def csi(priv, params, final)
    ps = params.split(";").map(&:to_i)
    n = ps[0] || 0
    n1 = n.zero? ? 1 : n
    @wrap_pending = false unless final == "m"
    case [priv, final]
    in ["", "A"] then @y = [@y - n1, 0].max
    in ["", "B"] then @y = [@y + n1, @rows - 1].min
    in ["", "C"] then @x = [@x + n1, @cols - 1].min
    in ["", "D"] then @x = [@x - n1, 0].max
    in ["", "E"] then @y = [@y + n1, @rows - 1].min; @x = 0
    in ["", "F"] then @y = [@y - n1, 0].max; @x = 0
    in ["", "G"] then @x = [n1 - 1, @cols - 1].min
    in ["", "H"] | ["", "f"]
      @y = [(ps[0] || 1) - 1, @rows - 1].min.clamp(0, @rows - 1)
      @x = [(ps[1] || 1) - 1, @cols - 1].min.clamp(0, @cols - 1)
    in ["", "J"]
      case n
      when 0
        screen[@y].fill(@x...@cols) { Cell.new(" ", nil) }
        ((@y + 1)...@rows).each { |r| screen[r] = blank_row }
      when 1
        (0...@y).each { |r| screen[r] = blank_row }
        screen[@y].fill(0..@x) { Cell.new(" ", nil) }
      when 2, 3 then @rows.times { |r| screen[r] = blank_row }
      end
    in ["", "K"]
      case n
      when 0 then (@x...@cols).each { |i| screen[@y][i] = Cell.new(" ", nil) }
      when 1 then (0..@x).each { |i| screen[@y][i] = Cell.new(" ", nil) }
      when 2 then screen[@y] = blank_row
      end
    in ["", "S"] then n1.times { scroll_up }
    in ["", "T"] then n1.times { screen.unshift(blank_row); screen.pop }
    in ["", "m"]
      @style = (ps.empty? || ps == [0]) ? nil : params
    in ["", "n"]
      @reply&.call("\e[#{@y + 1};#{@x + 1}R") if n == 6
    in ["?", "h"] | ["?", "l"]
      on = final == "h"
      ps.each do |p|
        case p
        when 1049
          if on && !@alt
            @alt_screen = blank_screen
            @alt = true
            @main_cursor = [@y, @x]
          elsif !on && @alt
            @alt = false
            @y, @x = @main_cursor
          end
        when 5 then @flashes += 1 if on
        end
      end
    in [_, "r"] | [_, "c"] | [_, "t"] | [_, "q"] | [_, "p"] then nil
    else @unknown["csi-#{priv}#{final}"] += 1
    end
  end
end
