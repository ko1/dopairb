# frozen_string_literal: true

module Dopairb
  # Every dependency on Reline internals lives in this file.
  #
  # Tested with Reline 0.6.x. Public hooks used: add_dialog_proc,
  # output_modifier_proc. Internal ones (prepended): LineEditor#input_key,
  # #handle_signal (called every 10ms while Reline waits for a key -- our
  # animation tick), #render, #render_finished, Core#readmultiline.
  module RelineAdapter
    SUPPORTED = Gem::Requirement.new(">= 0.5.0", "< 0.8")
    DIALOGS = %i[dopa_strip dopa_trail dopa_hud].freeze
    TICK = 1 / 30.0

    class << self
      attr_reader :fx, :editor

      def supported?
        defined?(Reline::VERSION) && SUPPORTED.satisfied_by?(Gem::Version.new(Reline::VERSION))
      end

      def install(fx)
        @fx = fx
        return false unless supported?
        return true if @installed
        Reline::LineEditor.prepend(LineEditorHook)
        Reline::Core.prepend(CoreHook)
        DIALOGS.each do |name|
          kind = name.to_s.delete_prefix("dopa_").to_sym
          Reline.add_dialog_proc(name, ->() { Dopairb::RelineAdapter.dialog(kind, self) }, nil)
        end
        @installed = true
      end

      def active?
        @installed && Dopairb.active? && !@broken
      end

      def keys? = active? && Dopairb.config.keys

      # Something went wrong inside our hooks: stop decorating, keep the REPL.
      def broken!(e)
        Dopairb.debug(e)
        @broken = true
      end

      def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # ---- called from hooks ------------------------------------------------

      def before_read(core)
        wrap_output_modifier(core)
        @editor = core.line_editor
        return unless keys?
        @fx.reset_line
        # Keep a lane of blank rows under the prompt for the effect strip.
        n = InputFx::STRIP_ROWS
        Term.write("\eD" * n + "\e[#{n}A")
      end

      def wrap_output_modifier(core)
        orig = core.output_modifier_proc
        return if orig&.instance_variable_get(:@dopairb)
        memo = [nil, nil, nil]
        wrapper = proc do |input, complete:|
          # highlights re-render the same text many times; colorize it once
          if memo[0] == input && memo[1] == complete
            colored = memo[2]
          else
            colored = orig ? orig.call(input, complete: complete) : nil
            memo.replace([input.dup, complete, colored])
          end
          if complete || !RelineAdapter.keys?
            colored
          else
            begin
              RelineAdapter.fx.apply(colored || Reline::Unicode.escape_for_print(input), input)
            rescue StandardError => e
              RelineAdapter.broken!(e)
              colored
            end
          end
        end
        wrapper.instance_variable_set(:@dopairb, true)
        core.output_modifier_proc = wrapper
      end

      def after_key(le, key, before, prev_x, pasting)
        @editor = le
        return if le.finished?
        after = [le.whole_lines, le.instance_variable_get(:@line_index), le.instance_variable_get(:@byte_pointer)]
        cur_x, = le.wrapped_cursor_position
        @fx.on_key(key.method_symbol, before, after, prev_x: prev_x, cur_x: cur_x, pasting: pasting)
      end

      def layout(le)
        key = [le.whole_lines, le.instance_variable_get(:@byte_pointer), le.instance_variable_get(:@line_index), le.screen_width, le.screen_scroll_top]
        return @layout[1] if @layout && @layout[0] == key
        lay = compute_layout(le)
        @layout = [key.map { |k| k.frozen? ? k : k.dup }, lay]
        lay
      end

      def compute_layout(le)
        x, y = le.wrapped_cursor_position
        top = le.screen_scroll_top
        rows = le.wrapped_prompt_and_input_lines.flatten(1)
        prompt, line = rows[y] || ["", ""]
        InputFx::Layout.new(cursor_x: x, cursor_row: y - top,
                            row_end_x: Term.str_width(prompt.to_s) + Term.str_width(line.to_s),
                            last_row: rows.size - 1 - top, screen_width: le.screen_width,
                            room_below: le.rest_height(y))
      end

      def dialog(kind, scope)
        return nil unless keys? && @editor
        lay = layout(@editor)
        info = case kind
               when :hud
                 r = @fx.hud_render(lay)
                 r && Reline::DialogRenderInfo.new(pos: Reline::CursorPos.new(r[0], -1), contents: r[1], height: 1)
               when :trail
                 r = @fx.trail_render(lay)
                 r && Reline::DialogRenderInfo.new(pos: Reline::CursorPos.new(r[0], -1), contents: r[1], height: 1)
               when :strip
                 return nil if scope.completion_journey_data
                 dy = lay.last_row - lay.cursor_row
                 return nil if lay.room_below - dy < InputFx::STRIP_ROWS
                 lines = @fx.strip_render(lay)
                 lines && Reline::DialogRenderInfo.new(pos: Reline::CursorPos.new(0, dy), contents: lines,
                                                       width: lay.screen_width - 1, height: InputFx::STRIP_ROWS)
               end
        info
      rescue StandardError => e
        broken!(e)
        nil
      end

      def tick(le)
        return unless keys?
        t = now
        return if @last_tick && t - @last_tick < TICK
        @last_tick = t
        @editor = le
        return unless @fx.animating?(t)
        le.__send__(:dopairb_refresh)
      rescue StandardError => e
        broken!(e)
      end

      def hl_dirty? = keys? && @fx.hl_dirty?

      # Snapshot what render_finished is about to print.
      def capture(le, rows, lines)
        @last_input = InputShot.new(rows: rows, lines: lines, code: le.whole_buffer, screen_width: le.screen_width)
      rescue StandardError => e
        Dopairb.debug(e)
        @last_input = nil
      end

      # The shot of the input that produced `code`, if it is still on screen.
      def take_input(code)
        shot = @last_input
        @last_input = nil
        return nil unless shot
        return nil unless shot.code.chomp == code.chomp
        return nil if shot.rows.size > Term.rows - 3
        shot
      end
    end

    module LineEditorHook
      def input_key(key)
        return super unless RelineAdapter.keys?
        if @in_pasting
          # keep pastes cheap: no layout work, just count
          RelineAdapter.fx.on_key(nil, nil, nil, prev_x: nil, cur_x: nil, pasting: true) unless key.char.nil?
          return super
        end
        before = nil
        prev_x = nil
        pasting = false
        begin
          before = [whole_lines.map(&:dup), @line_index, @byte_pointer]
          prev_x, = wrapped_cursor_position
        rescue StandardError => e
          RelineAdapter.broken!(e)
        end
        result = super
        if before
          begin
            RelineAdapter.after_key(self, key, before, prev_x, pasting)
          rescue StandardError => e
            RelineAdapter.broken!(e)
          end
        end
        result
      end

      def handle_signal
        super
        RelineAdapter.tick(self) unless @in_pasting || finished?
      end

      def render
        @cache.delete(:modified_lines) if RelineAdapter.hl_dirty?
        super
      end

      def render_finished
        if RelineAdapter.active?
          begin
            lines = []
            rows = @buffer_of_lines.size.times.flat_map do |i|
              prompt = Reline::Unicode.strip_non_printing_start_end(prompt_list[i])
              line = prompt + modified_lines[i]
              lines << [Term.str_width(prompt), whole_lines[i]]
              wrapped = split_line_by_width(line, screen_width)
              wrapped.last.empty? ? split_line_by_width("#{line} ", screen_width) : wrapped
            end
            RelineAdapter.capture(self, rows, lines)
          rescue StandardError => e
            Dopairb.debug(e)
          end
        end
        super
      end

      private

      def dopairb_refresh
        x, y = wrapped_cursor_position
        @dialogs.each do |d|
          update_each_dialog(d, x, y - screen_scroll_top) if RelineAdapter::DIALOGS.include?(d.name)
        end
        render
      end
    end

    module CoreHook
      def readmultiline(prompt = "", add_hist = false, &block)
        RelineAdapter.before_read(self) if RelineAdapter.active?
        super
      end
    end
  end
end
