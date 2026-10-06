# frozen_string_literal: true

module Dopairb
  # Snapshot of the submitted input as it sits on screen right above the cursor.
  class InputShot
    attr_reader :rows, :plain, :code, :prompt_widths, :lines, :screen_width

    # rows: physical rows (with SGR) exactly as Reline printed them
    # lines: [[prompt_width, code_line], ...] per logical line
    def initialize(rows:, lines:, code:, screen_width:)
      @rows = rows
      @plain = rows.map { |r| r.gsub(/\e\[[\d;?]*[A-Za-z]/, "").gsub(/[\x01\x02]/, "") }
      @lines = lines
      @code = code
      @screen_width = screen_width
    end

    def size = @rows.size

    # [row, x] on screen of (logical line index, byte column)
    def locate(line_idx, byte_col)
      row = 0
      @lines.each_with_index do |(pw, text), i|
        if i == line_idx
          prefix = text.byteslice(0, byte_col).to_s.scrub("?")
          x = pw + Term.str_width(prefix)
          return [row + x / @screen_width, x % @screen_width]
        end
        row += (pw + Term.str_width(text)) / @screen_width + 1
      end
      nil
    end

    # [[row, x, width], ...] for each word-bounded occurrence of name
    def find(name)
      return [] if name.nil? || name.empty?
      hits = []
      re = /(?<![\w@$])#{Regexp.escape(name)}(?![\w?!])/
      @lines.each_with_index do |(_, text), i|
        text.to_enum(:scan, re).each do
          b = Regexp.last_match.byteoffset(0)[0]
          pos = locate(i, b)
          hits << [pos[0], pos[1], Term.str_width(name)] if pos
        end
      end
      hits
    end
  end

  # Everything a scene needs to know about where it is drawing.
  Ctx = Struct.new(:w, :rows, :depth, :config, :rng, :input, :pre, :compact, keyword_init: true)

  class Scene
    attr_reader :ctx, :event

    def initialize(ctx, event = nil)
      @ctx = ctx
      @event = event
      @rng = ctx.rng
      @w = ctx.w
      setup
    end

    def setup; end

    def height = 1
    def length = 0.4
    def top? = false
    def big? = false
    # Played on the alternate screen (full screen, scrollback untouched).
    def alt? = false
    def mega? = false
    def bell? = mega?
    def trail = nil
    def shake(_t) = 0
    def flash_at = nil
    # Sound patch name and when (scene time) its impact should be heard.
    def sfx = nil
    def impact_at = flash_at || 0.0

    # Wind-up before the main animation (input row glow); 0 when not wanted.
    def pre = top? ? ctx.pre.to_f : 0.0
    def total_length = pre + length
    # Scenes that wait on something can end early.
    def done?(_t) = false

    # Top rows (the input) as canvas, or nil to leave them untouched.
    def draw_top(c, t)
      return nil unless t < pre
      glow_input(c, t / pre)
      true
    end

    def draw(_c, _t); end

    def w = @w
    def depth = ctx.depth

    def paint(text, col, bold: false)
      return text if depth == :none && !bold
      "#{Color.sgr(col, nil, bold, depth)}#{text}\e[0m"
    end

    def sub_bits(extra = [])
      bits = extra.dup
      return bits unless event
      bits << "+#{Fx.number_with_commas(event.gain)}" if event.gain.to_i > 0
      bits << "JACKPOT x#{Game::JACKPOT_MULT}" if event.flag?(:jackpot)
      bits << "CRITICAL x#{event.mult / (event.flag?(:fever) ? 2 : 1)}" if event.flag?(:critical)
      bits << "FEVER x2" if event.flag?(:fever) && !event.flag?(:fever_start)
      bits << "LEVEL UP LV #{event.level}" if event.flag?(:level_up)
      bits << "COMBO #{event.combo}" if event.combo.to_i > 1
      bits << "NEW RECORD" if event.flag?(:new_record) && !bits.include?("NEW RECORD")
      bits << "FIRST HIT" if event.flag?(:first_hit)
      bits << "RECOVERED after #{event.streak} error#{'s' if event.streak > 1}" if event.flag?(:comeback)
      bits
    end

    def sub_line(extra = [])
      sub_bits(extra).join("   ")
    end

    protected

    def plain_input(c, color = [150, 150, 160])
      ctx.input.plain.each_with_index { |r, y| c.put(0, y, r, color) }
    end

    # A hot band sweeping across the submitted code: "EXECUTE".
    def glow_input(c, p)
      band = p * (@w + 16) - 8
      ctx.input.plain.each_with_index do |r, y|
        x = 0
        r.each_char do |ch|
          d = (x - band - y * 2).abs
          col = d < 6 ? Color.mix([255, 255, 255], [255, 170, 40], d / 6.0) : [200, 200, 215]
          bg = d < 3 ? Color.mix([255, 120, 0], [60, 20, 0], d / 3.0) : nil
          c.put(x, y, ch, col, bg: bg, bold: d < 3)
          x += ch.ord < 0x80 ? 1 : Term.char_width(ch)
        end
      end
    end

    def combo_palette(combo = event&.combo.to_i)
      case combo
      when 0..2 then Color::ICE
      when 3..5 then Color::TOXIC
      when 6..9 then Color::GOLD
      when 10..19 then Color::FIRE
      else Color::NEON
      end
    end

    def combo_color(t = 0, combo = event&.combo.to_i)
      return Color.rainbow(t * 1.5) if combo >= 20
      Color.ramp(combo_palette(combo), 0.25)
    end

    def ease(t) = Fx.ease_out(t)

    def best_scale(text)
      ctx.compact ? nil : Fx.best_scale(text, @w)
    end
  end
end
