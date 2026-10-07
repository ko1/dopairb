# frozen_string_literal: true

require_relative "helper"
require "tmpdir"
require "dopairb/claude_code"

class TestClaudeCode < Test::Unit::TestCase
  CC = Dopairb::ClaudeCode

  def setup
    @dir = Dir.mktmpdir("dopacc")
    @env = ENV.to_h.slice("DOPACC_STATE", "DOPACC", "CLAUDE_CODE_NO_FLICKER", "CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN")
    ENV["DOPACC_STATE"] = File.join(@dir, "state.json")
    ENV.delete("DOPACC")
  end

  def teardown
    %w[DOPACC_STATE DOPACC CLAUDE_CODE_NO_FLICKER CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN].each { |k| ENV[k] = @env[k] }
    FileUtils.rm_rf(@dir)
  end

  # rand never hits the jackpot
  class NoLuck
    def rand(*) = 0.99
  end

  def hook(event, session: "s1", rng: NoLuck.new)
    CC::Hook.run(JSON.generate("hook_event_name" => event, "session_id" => session), rng: rng)
  end

  def test_combo_milestones_at_powers_of_two
    shows = (1..16).map { hook("PostToolUse") }.each_with_index.select { |plan, _| plan.first[:show] }.map { |_, i| i + 1 }
    assert_equal [8, 16], shows
    hook("PostToolUse")
    s = CC::State.read
    assert_equal 17, s["combo"]
    assert_equal 17, s["best"]
  end

  def test_failure_breaks_the_combo
    5.times { hook("PostToolUse") }
    assert_equal [{ sound: :crack }], hook("PostToolUseFailure")
    assert_equal 0, CC::State.read["combo"]
    assert_equal 5, CC::State.read["best"]
    assert_equal [{ sound: :error }], hook("PostToolUseFailure")
  end

  def test_fever_doubles_and_jackpot
    9.times { hook("PostToolUse") }
    before = CC::State.read["score"]
    hook("PostToolUse")
    assert_equal (10 + 10) * 2, CC::State.read["score"] - before
    lucky = Class.new { def rand(*) = 0.0 }.new
    plan = hook("PostToolUse", rng: lucky)
    assert_equal "JACKPOT!!", plan.first[:show]
  end

  def test_stop_shows_a_result_only_after_work
    assert_equal [{ sound: :result }], hook("Stop")
    3.times { hook("PostToolUse") }
    plan = hook("Stop")
    assert_match(/\A3 TOOLS  \+36  COMBO 3  BEST 3\z/, plan.first[:sub])
    assert_equal 0, CC::State.read["turn_tools"]
  end

  def test_new_session_resets_the_combo_but_not_the_best
    3.times { hook("PostToolUse") }
    hook("PostToolUse", session: "s2")
    s = CC::State.read
    assert_equal 1, s["combo"]
    assert_equal 3, s["best"]
  end

  def test_modes
    CC::State.update { |s| s["mode"] = "calm" }
    7.times { hook("PostToolUse") }
    assert_equal [{ sound: :mega }], hook("PostToolUse"), "COMBO 8 without taking the screen"
    CC::State.update { |s| s["mode"] = "off" }
    assert_equal [], hook("PostToolUse")
    CC::State.update { |s| s["mode"] = "on" }
    ENV["DOPACC"] = "off"
    assert_equal [], hook("PostToolUse")
  end

  def test_broken_input_is_harmless
    assert_equal [], CC::Hook.run("not json")
  end

  def test_install_round_trip_keeps_other_settings
    path = File.join(@dir, "settings.json")
    mine = { "hooks" => { "Stop" => [{ "matcher" => "", "hooks" => [{ "type" => "command", "command" => "notify" }] }] },
             "tui" => "fullscreen" }
    File.write(path, JSON.generate(mine))
    2.times { CC::Installer.install(path) }
    s = JSON.parse(File.read(path))
    CC::HOOK_EVENTS.each do |ev|
      assert_equal 1, s["hooks"][ev].sum { |m| m["hooks"].count { |h| CC::Installer.ours?(h) } }, ev
    end
    assert_match(/dopacc statusline\z/, s["statusLine"]["command"])
    assert CC::Installer.installed?(path)
    CC::Installer.uninstall(path)
    assert_equal mine, JSON.parse(File.read(path))
    assert File.exist?("#{path}.bak")
  end

  def test_install_keeps_a_foreign_statusline
    path = File.join(@dir, "settings.json")
    File.write(path, JSON.generate("statusLine" => { "type" => "command", "command" => "my-line" }))
    notes = CC::Installer.install(path)
    assert_equal "my-line", JSON.parse(File.read(path))["statusLine"]["command"]
    assert_equal 1, notes.size
  end

  def test_statusline
    CC::State.update { |s| s.merge!("combo" => 12, "score" => 12_345, "best" => 20) }
    line = CC.statusline.gsub(/\e\[[\d;]*m/, "")
    assert_equal "FEVER! COMBO 12  SCORE 12,345  BEST 20", line
    CC::State.update { |s| s["mode"] = "off" }
    assert_equal "dopacc off", CC.statusline.gsub(/\e\[[\d;]*m/, "")
  end

  def test_fullscreen_detection
    ENV["CLAUDE_CODE_NO_FLICKER"] = "1"
    assert CC::Screen.fullscreen?(@dir)
    ENV["CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN"] = "1"
    assert !CC::Screen.fullscreen?(@dir)
  end
end
