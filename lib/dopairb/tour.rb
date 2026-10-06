# frozen_string_literal: true

module Dopairb
  # `dopa gallery tour`: a full-screen slideshow of the whole collection.
  # Pieces you own are shown in color; the rest are silhouettes to hunt for.
  # → / space: next, ←: back, q: leave. Slides advance on their own.
  module Tour
    SLIDE = 4.0
    REVEAL = 0.35
    FPS = 30.0

    module_function

    def run(config, owned, start: 0)
      pieces = Gallery::PIECES
      depth = Term.depth(config)
      i = start % pieces.size
      stage = AltStage.new(Term.rows)
      Term.raw do
        stage.open
        begin
          loop do
            step = show(stage, pieces, i, owned, depth, config)
            break if step == :quit
            i = (i + step) % pieces.size
          end
        ensure
          stage.close
        end
      end
    rescue Interrupt
      nil
    end

    # Animate one slide; => how many slides to move (+1 on timeout) or :quit.
    def show(stage, pieces, i, owned, depth, config)
      t0 = now
      loop do
        t = now - t0
        stage.draw(frame(pieces[i], i, pieces.size, owned, depth, [t / REVEAL, 1.0].min, t))
        step = read_key(t < REVEAL ? 1 / FPS : [SLIDE * config.duration - t, 0.05].max)
        return step if step
        return 1 if t >= SLIDE * config.duration
      end
    end

    def frame(piece, i, total, owned, depth, reveal, t)
      rows, cols = Term.size
      w = cols - 1
      c = Canvas.new(w, rows)
      have = owned.include?(piece.id)
      star = Term.glyph("✦", "*")
      head = "#{star} DOPA IRB GALLERY #{star}   #{i + 1} / #{total}   collected #{owned.size}"
      c.put_center(0, head, Color.rainbow(t * 0.3), bold: true)
      aw, ah = Gallery.fit(piece, w - 6, rows - 6)
      ax = (w - aw) / 2
      ay = 2
      frame_col = have ? Color.mix([255, 240, 170], [190, 130, 30], (Math.sin(t * 3) + 1) / 2) : [70, 70, 90]
      c.fill_bg(frame_col, ax - 2, ay - 1, aw + 4, ah / 2 + 2)
      c.fill_bg([20, 20, 28], ax - 1, ay, aw + 2, ah / 2)
      Gallery.draw(c, piece, ax, ay, aw, ah, reveal: reveal, depth: depth) do |top, bot, _x, _r|
        have ? [top, bot] : [shadow(top), shadow(bot)]
      end
      cap = have ? "\"#{piece.title}\"  #{piece.artist}, #{piece.year}" : "? ? ?   (by #{piece.artist})"
      c.put_center(ay + ah / 2 + 1, cap, have ? [240, 230, 210] : [150, 150, 175], bold: have)
      c.put_center(rows - 1, "->/space next   <- back   q quit", [120, 120, 140])
      c.render(depth)
    end

    # Uncollected pieces keep their shapes but lose their colors.
    def shadow(color)
      Color.mix([12, 12, 22], [80, 80, 110], Color.luminance(color) / 255.0)
    end

    # Keys can arrive several at once (a held arrow key): all of them count.
    # => :quit, a step (+n / -n), or nil when nothing was typed.
    def read_key(timeout)
      return nil unless Term.input.wait_readable(timeout)
      s = Term.input.read_nonblock(256, exception: false)
      return nil unless String === s
      keys = s.scan(/\e[\[O][\d;]*[A-Za-z~]|\e|./m)
      return :quit if keys.any? { |k| ["q", "Q", "\e", "\x03"].include?(k) }
      step = keys.sum { |k| ["\e[D", "\eOD", "h", "p", "b"].include?(k) ? -1 : 1 }
      step.zero? ? nil : step
    end

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
