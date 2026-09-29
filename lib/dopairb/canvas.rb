# frozen_string_literal: true

module Dopairb
  # A w x h grid of cells with an optional braille sub-pixel layer
  # (2x4 dots per cell). Rendered to SGR-colored strings, one per row.
  class Canvas
    BRAILLE = [[0x01, 0x08], [0x02, 0x10], [0x04, 0x20], [0x40, 0x80]].freeze
    CONT = :cont

    attr_reader :w, :h

    def initialize(w, h)
      @w = w
      @h = h
      @ch = Array.new(h) { Array.new(w) }
      @fg = Array.new(h) { Array.new(w) }
      @bg = Array.new(h) { Array.new(w) }
      @bold = Array.new(h) { Array.new(w, false) }
      @dots = Array.new(h) { Array.new(w, 0) }
      @dotc = Array.new(h) { Array.new(w) }
    end

    def put(x, y, str, fg = nil, bg: nil, bold: false)
      x = x.round
      y = y.round
      return x if y < 0 || y >= @h
      str.each_char do |c|
        cw = c.ord < 0x80 ? 1 : Term.char_width(c)
        if cw <= 0
          next
        elsif cw == 2
          if x >= 0 && x + 1 < @w
            set(x, y, c, fg, bg, bold)
            set(x + 1, y, CONT, fg, bg, bold)
          end
        elsif x >= 0 && x < @w
          set(x, y, c, fg, bg, bold)
        end
        x += cw
      end
      x
    end

    def char_at(x, y)
      return nil unless x >= 0 && y >= 0 && x < @w && y < @h
      @ch[y][x]
    end

    def put_center(y, str, fg = nil, bg: nil, bold: false)
      put((@w - Term.str_width(str)) / 2, y, str, fg, bg: bg, bold: bold)
    end

    def bg(x, y, color)
      x = x.round
      y = y.round
      return unless x >= 0 && y >= 0 && x < @w && y < @h
      @bg[y][x] = color
    end

    def fill_bg(color, x0 = 0, y0 = 0, w = @w, h = @h)
      (y0...(y0 + h)).each do |y|
        next if y < 0 || y >= @h
        (x0...(x0 + w)).each do |x|
          @bg[y][x] = color if x >= 0 && x < @w
        end
      end
    end

    # Blend the existing background towards color by k (0..1). Unset bg is black.
    def tint_bg(color, k, x0 = 0, y0 = 0, w = @w, h = @h)
      (y0...(y0 + h)).each do |y|
        next if y < 0 || y >= @h
        (x0...(x0 + w)).each do |x|
          next if x < 0 || x >= @w
          @bg[y][x] = Color.mix(@bg[y][x] || [0, 0, 0], color, k)
        end
      end
    end

    # Sub-pixel dot; px in 0...(w*2), py in 0...(h*4)
    def dot(px, py, color)
      px = px.floor
      py = py.floor
      return if px < 0 || py < 0
      x = px >> 1
      y = py >> 2
      return if x >= @w || y >= @h
      @dots[y][x] |= BRAILLE[py & 3][px & 1]
      @dotc[y][x] = color
    end

    def line(x0, y0, x1, y1, color)
      steps = [((x1 - x0) * 2).abs, ((y1 - y0) * 4).abs, 1].max.ceil
      (0..steps).each do |i|
        t = i.fdiv(steps)
        dot((x0 + (x1 - x0) * t) * 2, (y0 + (y1 - y0) * t) * 4, color)
      end
    end

    # Ellipse in cell units; ry is visually halved by the cell aspect.
    def ring(cx, cy, r, color, density: 1.0)
      return if r <= 0
      n = [(r * 12 * density).ceil, 8].max
      n.times do |i|
        a = i * 2 * Math::PI / n
        dot((cx + Math.cos(a) * r) * 2, (cy + Math.sin(a) * r * 0.5) * 4, color)
      end
    end

    def render(depth, shake: 0)
      Array.new(@h) { |y| render_row(y, depth, shake) }
    end

    private

    def set(x, y, c, fg, bg, bold)
      @ch[y][x] = c
      @fg[y][x] = fg
      @bg[y][x] = bg if bg
      @bold[y][x] = bold
    end

    def render_row(y, depth, shake)
      chs = @ch[y]
      last = @w - 1
      last -= 1 while last >= 0 && chs[last].nil? && @dots[y][last] == 0 && @bg[y][last].nil?
      out = +""
      cur = nil
      if shake > 0
        out << (" " * shake)
      end
      start = shake < 0 ? -shake : 0
      limit = shake > 0 ? [last, @w - 1 - shake].min : last
      x = start
      while x <= limit
        c = chs[x]
        if c == CONT
          x += 1
          next
        end
        fg = @fg[y][x]
        bold = @bold[y][x]
        if c.nil?
          if @dots[y][x] != 0
            c = Term.utf8? ? (0x2800 + @dots[y][x]).chr(Encoding::UTF_8) : "."
            fg = @dotc[y][x]
            bold = false
          else
            c = " "
          end
        end
        style = [fg, @bg[y][x], bold]
        if style != cur
          out << (depth == :none && !bold && @bg[y][x].nil? ? "\e[0m" : Color.sgr(fg, @bg[y][x], bold, depth))
          cur = style
        end
        out << c
        x += 1
      end
      out << "\e[0m" if cur
      out
    end
  end
end
