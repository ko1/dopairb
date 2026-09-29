# frozen_string_literal: true

module Dopairb
  # Per-keystroke effects. Pure logic: it is told what changed in the line
  # editor and answers what to draw; RelineAdapter does the plumbing.
  class InputFx
    Layout = Struct.new(:cursor_x, :cursor_row, :row_end_x, :last_row, :screen_width, :room_below, keyword_init: true)

    STRIP_ROWS = 2
    OPEN = %i[PARENTHESIS_LEFT PARENTHESIS_LEFT_PARENTHESES BRACKET_LEFT BRACKET_LEFT_ARRAY BRACE_LEFT LAMBDA_BEGIN EMBEXPR_BEGIN].freeze
    CLOSE = %i[PARENTHESIS_RIGHT BRACKET_RIGHT BRACE_RIGHT EMBEXPR_END].freeze
    PAIRS = { "(" => ")", "[" => "]", "{" => "}", '#{' => "}" }.freeze
    STR_BEGIN = %i[STRING_BEGIN XSTRING_BEGIN REGEXP_BEGIN SYMBOL_BEGIN PERCENT_LOWER_W PERCENT_UPPER_W PERCENT_LOWER_I PERCENT_UPPER_I PERCENT_LOWER_X].freeze
    STR_END = %i[STRING_END REGEXP_END].freeze
    BLOCK_OPEN = %i[KEYWORD_CLASS KEYWORD_MODULE KEYWORD_DEF KEYWORD_IF KEYWORD_UNLESS KEYWORD_WHILE KEYWORD_UNTIL
                    KEYWORD_CASE KEYWORD_BEGIN KEYWORD_DO KEYWORD_FOR].freeze
    HISTORY_KEYS = %i[ed_prev_history ed_next_history ed_search_prev_history ed_search_next_history
                      ed_beginning_of_history ed_end_of_history vi_search_prev vi_search_next
                      incremental_search_history reverse_search_history forward_search_history].freeze
    COMPLETE_KEYS = %i[complete menu_complete menu_complete_backward completion_journey_up completion_journey_down
                       em_complete vi_complete].freeze

    Highlight = Struct.new(:from, :to, :born, :life, :kind)
    Popup = Struct.new(:text, :x, :born, :life, :palette, :rise, :prio)

    attr_reader :game

    def initialize(config, game, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, rng: Random.new)
      @config = config
      @game = game
      @clock = clock
      @rng = rng
      @parts = Fx::Particles.new(rng)
      @popups = []
      @highlights = []
      @inserts = []
      @last_kind = nil
      @paste_chars = 0
      @hl_was_active = false
      @last_hud = nil
    end

    def now = @clock.call
    def depth = Term.depth(@config)
    def lively? = @config.keys && @config.level >= 1
    def full? = @config.level >= 2

    # before/after: [lines, line_index, byte_pointer]; prev_x/cur_x: cursor columns
    def on_key(method_symbol, before, after, prev_x:, cur_x:, pasting: false)
      t = now
      if pasting
        @paste_chars += 1
        return
      end
      if @paste_chars > 0
        flush_paste(cur_x, t)
      end
      if method_symbol == :insert_multiline_text
        n = after[0].join("\n").size - before[0].join("\n").size
        @paste_chars = n.abs
        return flush_paste(cur_x, t)
      end

      b_lines, b_li, b_bp = before
      a_lines, a_li, a_bp = after
      if b_lines == a_lines
        return if [b_li, b_bp] == [a_li, a_bp]
        return moved(prev_x, cur_x, t)
      end

      old = b_lines.join("\n")
      new = a_lines.join("\n")
      if HISTORY_KEYS.include?(method_symbol)
        return history(new, cur_x, t)
      end
      pre = common_prefix(old, new)
      suf = common_suffix(old, new, pre)
      removed = old.byteslice(pre, old.bytesize - pre - suf).to_s
      added = new.byteslice(pre, new.bytesize - pre - suf).to_s
      if COMPLETE_KEYS.include?(method_symbol) && !added.empty?
        return completed(pre, added, cur_x, t)
      end
      if a_lines.size > b_lines.size && added.start_with?("\n")
        @game.key(:newline)
        pop("CHARGE LV#{a_lines.size}", cur_x, t, Color::FIRE, life: 0.6)
        @parts.burst(cur_x + 2, 0.2, 14, at: t, speed: 24, life: 0.4, palette: Color::FIRE, gravity: 6, angle: 0, arc: Math::PI) if full?
        @last_kind = :newline
        return
      end
      if !removed.empty? && added.empty?
        return deleted(removed, cur_x, t)
      end
      if added.size == 1 && removed.empty?
        return inserted(added, pre, new, cur_x, t)
      end
      unless added.empty?
        @game.key(:insert, added[0])
        spark(cur_x, t, 2)
      end
    rescue StandardError => e
      Dopairb.debug(e)
    end

    def animating?(t = now)
      return true if @parts.alive?(t)
      return true if @popups.any? { |p| t - p.born < p.life }
      return true if @inline && t - @inline.born < @inline.life + 0.1
      return true if @inserts.any? { |it| t - it < 0.4 }
      return true if hl_dirty?(t)
      hud = @config.hud ? hud_key(t) : nil
      if hud != @last_hud
        @last_hud = hud
        return true
      end
      false
    end

    # True while highlights are live and for the one render after they end.
    def hl_dirty?(t = now)
      active = @highlights.any? { |h| t - h.born < h.life }
      dirty = active || @hl_was_active
      @hl_was_active = active
      dirty
    end

    def reset_line
      @inline = nil
      @highlights.clear
      @inserts.clear
      @popups.clear
      @parts.clear
    end

    # ---- rendering -------------------------------------------------------

    def hud_render(lay, t = now)
      return nil unless @config.hud
      text = hud_text(lay.screen_width - lay.row_end_x - 4, t)
      return nil unless text
      x = lay.screen_width - Term.str_width(text) - 1
      return nil if x <= lay.row_end_x + 1
      heat = @game.heat(t)
      bg = Color.mix([22, 26, 44], [90, 26, 10], heat)
      fg = Color.mix([120, 135, 170], [255, 215, 120], heat)
      gauge_on = Color.mix([80, 110, 170], Color.ramp(Color::FIRE, 0.35), heat)
      c = Canvas.new(Term.str_width(text), 1)
      c.put(0, 0, text, fg, bg: bg, bold: heat > 0.5)
      g = text.index("[")
      if g
        cells = 8
        filled = (@game.charge / Game::CHARGE_MAX * cells).round
        cells.times do |i|
          c.put(g + 1 + i, 0, Term.glyph(i < filled ? "⣿" : "⣀", i < filled ? "#" : "."), i < filled ? gauge_on : [70, 70, 90], bg: bg)
        end
      end
      [x, c.render(depth)]
    end

    def hud_key(t)
      [hud_text(200, t), (@game.heat(t) * 12).round, (@game.charge / Game::CHARGE_MAX * 8).round]
    end

    def trail_render(lay, t = now)
      return nil unless lively?
      return nil unless lay.cursor_x == lay.row_end_x
      if @inline && t - @inline.born < @inline.life
        return inline_render(lay, t)
      end
      recent = @inserts.select { |it| t - it < 0.35 }
      return nil if recent.empty?
      len = [recent.size + 1, 6].min
      room = lay.screen_width - lay.cursor_x - 2
      len = [len, room].min
      return nil if len <= 0
      c = Canvas.new(len, 1)
      glyphs = [Term.glyph("✦", "*"), "*", "+", "'", "."]
      age = t - recent.max
      len.times do |i|
        f = i.fdiv(len) + age * 2
        next if f > 1
        c.put(i, 0, glyphs[(i + (t * 30).to_i) % glyphs.size], Color.ramp(Color::FIRE, f), bold: i.zero?)
      end
      [lay.cursor_x + 1, c.render(depth)]
    end

    # Popup on the cursor row, for moments when the strip below is covered.
    def inline_render(lay, t)
      p = @inline
      room = lay.screen_width - lay.cursor_x - 2
      text = p.text[0, room]
      return nil if text.nil? || text.empty?
      age = (t - p.born) / p.life
      c = Canvas.new(text.size, 1)
      text.each_char.with_index do |ch, i|
        sweep = (i - age * text.size * 2.5).abs < 1.5
        col = sweep ? [255, 255, 255] : Color.ramp(p.palette, 0.1 + age * 0.7)
        c.put(i, 0, ch, col, bg: age < 0.15 ? Color.ramp(p.palette, 0.5) : nil, bold: age < 0.6)
      end
      [lay.cursor_x + 1, c.render(depth)]
    end

    def strip_render(lay, t = now)
      return nil unless lively?
      @popups.reject! { |p| t - p.born > p.life }
      @parts.prune(t)
      return nil if @popups.empty? && @parts.empty?
      w = lay.screen_width - 1
      c = Canvas.new(w, STRIP_ROWS)
      @parts.draw(c, t)
      @popups.each do |p|
        age = (t - p.born) / p.life
        y = p.rise && age > 0.5 ? 0 : 1
        col = age < 0.15 ? [255, 255, 255] : Color.ramp(p.palette, 0.1 + age * 0.7)
        bg = age < 0.12 ? Color.ramp(p.palette, 0.4) : nil
        x = [[p.x, 0].max, w - p.text.size].min
        c.put(x, y, p.text, col, bg: bg, bold: age < 0.6)
      end
      c.render(depth)
    end

    # Decorate IRB's colorized input with the live highlights.
    def apply(colored, raw, t = now)
      live = @highlights.select { |h| t - h.born < h.life }
      return colored if live.empty? || colored.nil?
      spans = live.map do |h|
        from = raw.byteslice(0, h.from).to_s.size
        to = raw.byteslice(0, h.to).to_s.size
        [from, to, h, (t - h.born) / h.life]
      end
      out = +""
      cur = +""
      ci = 0
      colored.scan(/\e\[[\d;]*m|\e\[?[\d;?]*[A-Za-z]|./m) do |tok|
        if tok.start_with?("\e")
          out << tok
          if tok.end_with?("m")
            (tok == "\e[0m" || tok == "\e[m") ? cur.clear : cur << tok
          end
          next
        end
        if tok != "\n" && (span = spans.reverse.find { |f, to, _, _| ci >= f && ci < to })
          out << style(span, ci, tok, cur)
        else
          out << tok
        end
        ci += 1
      end
      ci == raw.size ? out : colored
    end

    private

    def hud_text(space, t)
      score = Fx.number_with_commas(@game.score)
      mult = @game.multiplier(t)
      m = mult > 1.04 ? format(" x%.1f", mult) : ""
      full = " COMBO #{format('%02d', @game.combo)}  SCORE #{score}  [#{' ' * 8}]#{m} "
      return full if Term.str_width(full) <= space
      short = " C#{format('%02d', @game.combo)} #{score} "
      Term.str_width(short) <= space ? short : nil
    end

    def style(span, ci, ch, cur)
      from, to, h, f = span
      d = depth
      case h.kind
      when :flash
        bg = Color.ramp(Color::FIRE, 0.05 + f * 0.8)
        "#{Color.sgr([20, 10, 0], bg, true, d)}#{ch}\e[0m#{cur}"
      when :pair
        pulse = 0.5 + 0.5 * Math.cos(f * Math::PI * 5)
        bg = Color.mix([255, 190, 40], [255, 255, 200], pulse)
        bg = Color.mix(bg, [40, 30, 10], f)
        "#{Color.sgr([30, 20, 0], bg, true, d)}#{ch}\e[0m#{cur}"
      when :range, :lock
        base = h.kind == :lock ? [0, 170, 200] : [70, 60, 150]
        sweep = from + (to - from) * [f * 2.5, 1].min
        bg = (ci - sweep).abs < 1.5 ? [230, 250, 255] : Color.mix(base, [20, 20, 30], f)
        bgs = d == :none ? "\e[7m" : "\e[#{Color.bg_code(bg, d)}m"
        "#{bgs}#{ch}\e[0m#{cur}"
      when :reveal
        head = from + (to - from) * [f * 1.6, 1].min
        if ci > head
          "#{Color.sgr([70, 70, 85], nil, false, d)}#{ch}\e[0m#{cur}"
        elsif head - ci < 1.5
          "#{Color.sgr([20, 20, 30], [220, 240, 255], true, d)}#{ch}\e[0m#{cur}"
        else
          ch
        end
      else
        ch
      end
    end

    def inserted(ch, off, new, cur_x, t)
      resumed = @game.key(:insert, ch)
      recovering = @last_kind == :delete
      @last_kind = :insert
      @inserts << t
      @inserts.shift while @inserts.size > 8
      return unless lively?
      if new.size < 4000
        @highlights.reject! { |h| h.kind == :flash }
        @highlights << Highlight.new(off, off + ch.bytesize, t, 0.18, :flash)
      end
      spark(cur_x, t, full? ? 4 : 1)
      if resumed == :resume
        pop("CHARGE!", cur_x - 3, t, Color::FIRE, life: 0.7, rise: true, prio: 3)
        @parts.burst(cur_x, 0.0, 26, at: t, speed: 34, life: 0.55, palette: Color::FIRE, gravity: 10) if full?
      elsif recovering
        pop("RECOVERY", cur_x - 4, t, Color::TOXIC, life: 0.55)
      end
      streak = @game.typing_combo
      if [20, 50, 100, 200].include?(streak)
        pop("STREAK #{streak}!", cur_x - 5, t, streak >= 100 ? Color::NEON : Color::GOLD, life: 0.9, rise: true, prio: 3)
        @parts.burst(cur_x, 0.5, 30, at: t, speed: 40, life: 0.6, palette: Color::GOLD, gravity: 12) if full?
      end
      syntax_moment(ch, off, new, cur_x, t)
    end

    def syntax_moment(ch, off, new, cur_x, t)
      return unless defined?(Prism) && new.size < 20_000
      if ")]}\"'`/>|!".include?(ch)
        tokens = Prism.lex(new).value.map(&:first)
        if (open = match_bracket(tokens, off))
          @game.key(:bracket)
          @highlights << Highlight.new(open, open + (tokens.find { |tk| tk.location.start_offset == open }&.value&.bytesize || 1), t, 0.6, :pair)
          @highlights << Highlight.new(off, off + 1, t, 0.6, :pair)
          @highlights.reject! { |h| h.kind == :flash }
          pop("NICE!", cur_x - 3, t, Color::GOLD, life: 0.6, rise: true, prio: 2)
          @parts.burst(cur_x - 1, 0.0, 12, at: t, speed: 26, life: 0.4, palette: Color::GOLD, gravity: 8) if full?
        elsif (range = match_string(tokens, off))
          @game.key(:string)
          @highlights << Highlight.new(range[0], range[1], t, 0.45, :range)
          @parts.burst(cur_x - 1, 0.0, 6, at: t, speed: 16, life: 0.35, palette: Color::ICE, gravity: 6) if full?
        end
      elsif ch == "d" && new.byteslice(off - 2, 3) == "end"
        tokens = Prism.lex(new).value.map(&:first)
        if (start = match_block(tokens, off - 2))
          @game.key(:block)
          @highlights << Highlight.new(start, off + 1, t, 0.55, :range)
          pop("SEALED!", cur_x - 4, t, Color::NEON, life: 0.7, rise: true, prio: 2)
          @parts.burst(cur_x - 2, 0.0, 16, at: t, speed: 30, life: 0.5, palette: Color::NEON, gravity: 8) if full?
        end
      end
    rescue StandardError => e
      Dopairb.debug(e)
    end

    def match_bracket(tokens, off)
      stack = []
      tokens.each do |tk|
        o = tk.location.start_offset
        if OPEN.include?(tk.type)
          stack << tk
        elsif CLOSE.include?(tk.type)
          opener = stack.pop
          if o == off
            return nil unless opener && PAIRS[opener.value] == tk.value
            return opener.location.start_offset
          end
        end
        break if o > off
      end
      nil
    end

    def match_string(tokens, off)
      stack = []
      tokens.each do |tk|
        o = tk.location.start_offset
        if STR_BEGIN.include?(tk.type)
          stack << o
        elsif STR_END.include?(tk.type)
          b = stack.pop
          return (b ? [b, tk.location.end_offset] : nil) if tk.location.end_offset == off + 1
        end
        break if o > off
      end
      nil
    end

    def match_block(tokens, end_off)
      stack = []
      tokens.each_with_index do |tk, i|
        o = tk.location.start_offset
        if BLOCK_OPEN.include?(tk.type)
          stack << o unless tk.type == :KEYWORD_DEF && endless_def?(tokens, i)
        elsif tk.type == :KEYWORD_END
          b = stack.pop
          return b if o == end_off
        end
        break if o > end_off
      end
      nil
    end

    def endless_def?(tokens, i)
      depth = 0
      tokens[(i + 1)..].each do |tk|
        case tk.type
        when :PARENTHESIS_LEFT, :PARENTHESIS_LEFT_PARENTHESES then depth += 1
        when :PARENTHESIS_RIGHT then depth -= 1
        when :EQUAL then return depth.zero?
        when :NEWLINE, :SEMICOLON then return false if depth.zero?
        end
      end
      false
    end

    def deleted(removed, cur_x, t)
      @game.key(:delete)
      @last_kind = :delete
      @highlights.clear
      return unless lively?
      glyph = removed.gsub(/\s/, "").chars.last || "."
      glyph = "." unless Term.char_width(glyph) == 1
      @parts.add(cur_x, 0.0, (@rng.rand - 0.5) * 6, 3, at: t, life: 0.45, palette: [[255, 255, 255], [255, 120, 120], [120, 40, 40]], glyph: glyph, gravity: 16)
      n = full? ? 7 : 3
      n.times do
        @parts.add(cur_x + 0.5, 0.1, (@rng.rand - 0.5) * 22, -2 + @rng.rand * 6, at: t, life: 0.4 + @rng.rand * 0.2,
                   palette: [[255, 200, 200], [230, 60, 60], [80, 20, 20]], glyph: ["'", ",", ".", "`"][@rng.rand(4)], gravity: 26, drag: 1.0)
      end
    end

    def moved(prev_x, cur_x, t)
      @game.key(:move)
      @last_kind = :move
      return unless lively? && prev_x && cur_x && prev_x != cur_x
      dir = cur_x > prev_x ? 1 : -1
      span = (cur_x - prev_x).abs
      steps = [span, 30].min
      steps.times do |i|
        x = cur_x - dir * (i + 1) * span.fdiv(steps)
        @parts.add(x, 0.15, dir * 4.0, 0, at: t + i * 0.004, life: 0.12 + 0.2 * (1 - i.fdiv(steps)), palette: Color::ICE)
      end
    end

    def history(new, cur_x, t)
      @game.key(:history)
      @last_kind = :history
      return unless lively?
      @highlights.clear
      @highlights << Highlight.new(0, new.bytesize, t, 0.35, :reveal) if new.size < 4000
      pop("<< REWIND", cur_x - 10, t, Color::ICE, life: 0.5)
    end

    def completed(off, added, cur_x, t)
      @game.key(:complete)
      @last_kind = :complete
      return unless lively?
      @highlights.reject! { |h| h.kind == :flash }
      @highlights << Highlight.new(off, off + added.bytesize, t, 0.5, :lock)
      @inline = Popup.new("<< LOCK ON", cur_x + 1, t, 0.6 * @config.duration, Color::ICE, false, 2)
      @parts.burst(cur_x, 0.2, 10, at: t, speed: 28, life: 0.3, palette: Color::ICE, gravity: 0) if full?
    end

    def flush_paste(cur_x, t)
      n = @paste_chars
      @paste_chars = 0
      @game.key(:paste)
      @last_kind = :paste
      pop("PASTE x#{n}", (cur_x || 0) - 6, t, Color::NEON, life: 0.8, rise: true) if lively?
    end

    def spark(cur_x, t, n)
      return if n <= 0
      @parts.burst(cur_x - 0.5, -0.3, n, at: t, speed: 14, life: 0.35, palette: Color::FIRE, gravity: 20, angle: Math::PI / 2, arc: Math::PI * 1.2)
    end

    # One popup at a time: a newer one wins unless the current one is more important and still fresh.
    def pop(text, x, t, palette, life: 0.5, rise: false, prio: 1)
      cur = @popups.last
      return if cur && t - cur.born < cur.life * 0.5 && cur.prio > prio
      @popups.replace([Popup.new(text, x, t, life * @config.duration, palette, rise, prio)])
    end

    def common_prefix(a, b)
      n = [a.bytesize, b.bytesize].min
      i = 0
      i += 1 while i < n && a.getbyte(i) == b.getbyte(i)
      i -= 1 while i > 0 && !char_boundary?(a, i)
      i
    end

    def common_suffix(a, b, pre)
      n = [a.bytesize, b.bytesize].min - pre
      i = 0
      i += 1 while i < n && a.getbyte(a.bytesize - 1 - i) == b.getbyte(b.bytesize - 1 - i)
      i -= 1 while i > 0 && !char_boundary?(a, a.bytesize - i)
      i
    end

    def char_boundary?(s, i)
      b = s.getbyte(i)
      b.nil? || (b & 0xC0) != 0x80
    end
  end
end
