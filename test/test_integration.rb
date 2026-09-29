# frozen_string_literal: true

require_relative "helper"
require_relative "support/pty_driver"
require "open3"
require "tmpdir"

# End-to-end runs on a pseudo terminal (spec section 10).
class TestIntegration < Test::Unit::TestCase
  include DopairbTestHelper

  def start(*args, rows: 30, cols: 100, env: {})
    @log = File.join(Dir.mktmpdir("dopairb-log"), "debug.log")
    @d = PTYDriver.dopairb("--no-intro", *args, rows: rows, cols: cols, env: { "DOPAIRB_DEBUG" => @log }.merge(env))
    @d.wait_for(/\(main\):001>/, timeout: 20)
    @d.settle(quiet: 0.3)
    @d
  end

  def teardown
    @d&.close
    if @log
      log = File.exist?(@log) ? File.read(@log) : ""
      assert_equal "", log, "dopairb swallowed internal errors"
    end
  end

  def run_line(line, delay: 0.01)
    @d.type(line, delay: delay)
    @d.send_keys("\r")
    @d.settle
  end

  def test_result_is_left_as_plain_text
    start
    run_line("(1..100).sum")
    text = @d.all_text
    assert_match(/^dopairb\(main\):001> \(1\.\.100\)\.sum$/, text)
    assert_match(/^=> 5050$/, text)
  end

  def test_errors_are_complete_and_comeback_follows
    start
    run_line("foo_bar_baz")
    assert_match(/undefined local variable or method 'foo_bar_baz' for main \(NameError\)/, @d.all_text)
    run_line("1 + )")
    assert_match(/SyntaxError/, @d.all_text)
    assert_match(/unexpected '\)'/, @d.all_text)
    run_line("21 * 2")
    assert_match(/COMEBACK!/, @d.all_text)
    assert_match(/^=> 42$/, @d.all_text)
  end

  def test_fast_typing_is_not_lost
    start
    expr = "[" + (1..60).map(&:to_s).join(", ") + "].sum"
    run_line(expr, delay: 0.002)
    assert_match(/^=> 1830$/, @d.all_text)
    assert_includes @d.all_text.delete("\n"), expr
  end

  def test_bracketed_paste
    start
    # like IRB, a pasted block is one input that still needs Enter
    @d.send_keys("\e[200~a = 10\rb = 32\ra + b\e[201~")
    @d.settle
    assert_match(/a = 10\n.*b = 32\n.*a \+ b/, @d.all_text)
    @d.send_keys("\r")
    @d.settle
    assert_match(/^=> 42$/, @d.all_text)
  end

  def test_output_order
    start
    run_line(%q{puts "one"; warn "two"; $stdout.print "three\n"; nil})
    lines = @d.all_text.lines.map(&:chomp)
    i = lines.index("one")
    assert_not_nil i
    # a one-line badge may sit between the program output and the result
    assert_equal ["one", "two", "three", "=> nil"], lines[i, 5].grep_v(/\A\S+ FIRST HIT/)
  end

  def test_interrupt
    start
    @d.type("sleep 10\r")
    sleep 0.8
    @d.send_keys("\x03")
    @d.settle
    assert_match(/INTERRUPTED/, @d.all_text)
    assert_match(/IRB::Abort/, @d.all_text)
  end

  def test_exit_shows_result
    start
    run_line("1")
    @d.type("exit\r")
    assert_equal 0, @d.wait_exit(timeout: 15)
    sleep 0.2
    text = @d.all_text
    assert_match(/DOPA IRB RESULT/, text)
    assert_match(/EVALS\s+1$/, text)
  end

  def test_narrow_terminal
    start(rows: 12, cols: 30)
    run_line("[1, 2, 3].sum")
    run_line("nope")
    run_line("6 * 7")
    assert_match(/^=> 42$/, @d.all_text)
  end

  def test_no_color
    start(env: { "NO_COLOR" => "1" })
    run_line("[1, 2].map { _1 * 2 }")
    run_line("nope")
    raw = @d.raw_output.force_encoding(Encoding::UTF_8).scrub
    assert_not_match(/\e\[[\d;]*[34]8;[25];/, raw)
    assert_match(/^=> \[2, 4\]$/, @d.all_text)
  end

  def test_intensity_off_is_plain_irb
    start("--intensity=off")
    run_line("(1..10).sum")
    raw = @d.raw_output.force_encoding(Encoding::UTF_8).scrub
    assert_not_match(/COMBO|SCORE|FIRST HIT/, raw)
    assert_not_match(/[⠀-⣿]/, raw)
    assert_match(/^=> 55$/, @d.all_text)
  end

  def test_runtime_toggle
    start
    run_line("dopa off")
    run_line("40 + 2")
    assert_not_match(/FIRST HIT/, @d.all_text)
    run_line("dopa normal")
    run_line("dopa")
    assert_match(/intensity\s+normal/, @d.all_text)
  end

  def test_multiline_definition
    start
    @d.type("def dopa_twice(x)\r", delay: 0.03)
    @d.type("x * 2\r", delay: 0.03)
    @d.type("end\r", delay: 0.03)
    @d.settle
    run_line("dopa_twice(21)")
    assert_match(/NEW ABILITY/, @d.all_text)
    assert_match(/^=> 42$/, @d.all_text)
  end

  def test_non_tty_has_no_control_sequences
    out, status = Open3.capture2e({ "IRBRC" => File::NULL, "TERM" => "xterm-256color" }, RbConfig.ruby, "-I#{PTYDriver::ROOT}/lib",
                                  "#{PTYDriver::ROOT}/exe/dopairb", stdin_data: "(1..100).sum\nfoo\n1\n")
    assert status.success?
    assert_not_match(/\e/, out)
    assert_match(/^5050$/, out)
    assert_match(/NameError/, out)
  end
end
