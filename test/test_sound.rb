# frozen_string_literal: true

require_relative "helper"
require "tmpdir"

class TestSound < Test::Unit::TestCase
  S = Dopairb::Sound

  def setup
    @path = ENV["PATH"]
    S.reset_backend
    S.instance_variable_set(:@wsl, nil)
  end

  def teardown
    ENV["PATH"] = @path
    S.reset_backend
    S.instance_variable_set(:@wsl, nil)
  end

  def test_every_patch_is_a_short_valid_wav
    S::PATCHES.each do |name, patch|
      samples, impact = patch.call
      dur = samples.size.fdiv(S::RATE)
      assert_operator dur, :>, 0.01, name
      assert_operator dur, :<, name == :finale ? Dopairb::Scenes::Finale::Timeline.length + 1 : 2.0, name
      assert_operator impact, :<=, dur, name
      wav = S.wav(samples)
      assert_operator wav.byteslice(44..).unpack("s<*").map(&:abs).max, :<=, 32_000 * 0.9 + 1, "#{name} is normalized"
      riff, size, wave, fmt, _, pcm, ch, rate, _, _, bits, data, dsize = wav.unpack("a4Va4a4VvvVVvva4V")
      assert_equal ["RIFF", "WAVE", "fmt ", 1, 1, S::RATE, 16, "data"], [riff, wave, fmt, pcm, ch, rate, bits, data]
      assert_equal wav.bytesize - 8, size
      assert_equal samples.size * 2, dsize
    end
  end

  def fake_bin(dir, name, body = "exit 0")
    path = File.join(dir, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, path)
    path
  end

  def test_backend_order
    Dir.mktmpdir do |d|
      ENV["PATH"] = d
      assert_nil S.backend
      fake_bin(d, "aplay")
      S.reset_backend
      assert_equal :fast, S.backend[0]
      assert_match(/aplay\z/, S.backend[1][0])
      fake_bin(d, "paplay")
      S.reset_backend
      S.instance_variable_set(:@wsl, false)
      assert_match(/paplay\z/, S.backend[1][0])
    end
  end

  def test_wsl_without_wslg_uses_powershell_and_skips_key_sounds
    Dir.mktmpdir do |d|
      ENV["PATH"] = d
      fake_bin(d, "powershell.exe")
      fake_bin(d, "wslpath", "echo C:\\\\x.wav")
      S.instance_variable_set(:@wsl, true)
      S.reset_backend
      assert_equal :slow, S.backend[0]
      assert !S.fast?
      assert_equal false, S.play(:key)
    end
  end

  def test_play_runs_the_player_without_counting_as_program_output
    Dir.mktmpdir do |d|
      log = File.join(d, "played")
      ENV["PATH"] = d
      fake_bin(d, "aplay", %(echo "$@" >> #{log}))
      S.reset_backend
      Dopairb::OutputTap.start
      assert S.play(:nice)
      assert_equal false, S.play(:nice), "same sound right away is throttled"
      Dopairb::OutputTap.stop
      assert !Dopairb::OutputTap.output?
      20.times { break if File.exist?(log); sleep 0.05 }
      assert_match(/nice\.wav/, File.read(log))
    end
  end

  def test_finale_follows_duration
    _, _, len1 = S.file(:finale, 1.0)
    _, _, len2 = S.file(:finale, 2.0)
    # event times stretch, the ring-out after the rank stamp does not
    assert_in_delta Dopairb::Scenes::Finale::Timeline.rank, len2 - len1, 0.3
  end

  def test_warm_up_renders_everything_in_the_background_and_reuses_it
    Dir.mktmpdir do |d|
      ENV["PATH"] = d
      fake_bin(d, "aplay")
      S.reset_backend
      S.instance_variable_set(:@dir, File.join(d, "sfx"))
      S.instance_variable_set(:@files, nil)
      th = S.warm_up(1.0)
      assert_kind_of Thread, th
      th.join(30)
      S::PATCHES.each_key { |n| assert S.cached(S.key_for(n, 1.0)), n.to_s }
      assert_nil S.warm_up(1.0), "nothing left to render"
      path, = S.cached(S.key_for(:mega, 1.0))
      before = File.mtime(path)
      S.instance_variable_set(:@files, nil)
      sleep 0.01
      got, impact, len = S.file(:mega)
      assert_equal path, got
      assert_equal before, File.mtime(path), "a cached sound is not re-synthesized"
      assert_operator len, :>, impact
    ensure
      S.instance_variable_set(:@dir, nil)
      S.instance_variable_set(:@files, nil)
      S.instance_variable_set(:@warming, nil)
    end
  end

  def test_input_fx_triggers_key_sounds
    played = []
    cfg = Dopairb::Config.new
    fx = Dopairb::InputFx.new(cfg, Dopairb::Game.new, sound: ->(n) { played << n })
    fx.on_key(:ed_insert, [[""], 0, 0], [["("], 0, 1], prev_x: 0, cur_x: 1)
    fx.on_key(:ed_insert, [["("], 0, 1], [["()"], 0, 2], prev_x: 1, cur_x: 2)
    fx.on_key(:em_delete_prev_char, [["()"], 0, 2], [["("], 0, 1], prev_x: 2, cur_x: 1)
    assert_equal %i[key key nice delete], played
  end

  def test_sound_setting
    c = Dopairb::Config.new
    assert_equal :off, c.sound
    assert_equal :sfx, c.set(:sound, "on").sound
    assert_equal :bell, c.set(:sound, "bell").sound
    assert_equal :off, c.set(:sound, "off").sound
    assert_raise(ArgumentError) { c.set(:sound, "loud") }
  end
end
