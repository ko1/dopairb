# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "rbconfig"

module Dopairb
  # Sound effects synthesized at runtime (no bundled audio) and played by
  # whatever the OS offers: paplay (PulseAudio, incl. WSLg), aplay, afplay,
  # or PowerShell on WSL without WSLg. Falls back to the terminal bell.
  module Sound
    RATE = 22_050

    # Waveform building blocks. Each returns an array of floats in -1..1.
    module Synth
      module_function

      def silence(dur) = Array.new((dur * RATE).round, 0.0)

      def tone(freq, dur, wave: :square, vol: 0.3, slide_to: nil, attack: 0.004, decay: nil, vibrato: 0.0)
        n = (dur * RATE).round
        phase = 0.0
        Array.new(n) do |i|
          t = i.fdiv(RATE)
          f = slide_to ? freq * (slide_to.fdiv(freq))**(i.fdiv(n)) : freq
          f *= 1 + vibrato * Math.sin(t * 2 * Math::PI * 6) if vibrato > 0
          phase += f / RATE
          p = phase % 1.0
          s = case wave
              when :square then p < 0.5 ? 1.0 : -1.0
              when :saw then 2 * p - 1
              when :triangle then 1 - 4 * (p - 0.5).abs
              else Math.sin(phase * 2 * Math::PI)
              end
          env = t < attack ? t / attack : 1.0
          env *= decay ? Math.exp(-t / decay) : (1 - i.fdiv(n))
          s * env * vol
        end
      end

      # Low-passed white noise; smooth 0..1 (higher = darker).
      def noise(dur, vol: 0.4, decay: 0.1, smooth: 0.0, rng: Random.new(7))
        prev = 0.0
        Array.new((dur * RATE).round) do |i|
          prev = prev * smooth + (rng.rand * 2 - 1) * (1 - smooth)
          prev * vol * Math.exp(-i.fdiv(RATE) / decay)
        end
      end

      def seq(*parts) = parts.flatten

      def mix(*tracks)
        len = tracks.map(&:size).max || 0
        Array.new(len) { |i| tracks.sum { |tr| tr[i] || 0.0 } }
      end

      def at(offset, track) = silence(offset) + track

      def arp(freqs, step, **kw)
        freqs.map { |f| tone(f, step, **kw) }.flatten
      end

      # Mix track into buf starting at t seconds (grows buf as needed).
      def add(buf, t, track, gain = 1.0)
        o = (t * RATE).round
        need = o + track.size
        buf.fill(0.0, buf.size...need) if need > buf.size
        track.each_with_index { |v, i| buf[o + i] += v * gain }
        buf
      end

      # Noise that swells instead of decaying.
      def riser(dur, vol: 0.3, smooth: 0.3, rng: Random.new(11))
        n = (dur * RATE).round
        prev = 0.0
        Array.new(n) do |i|
          prev = prev * smooth + (rng.rand * 2 - 1) * (1 - smooth)
          prev * vol * (i.fdiv(n)**2)
        end
      end

      def boom(dur = 0.6, vol: 0.6, low: 80)
        mix(noise(dur, vol: vol * 0.8, decay: dur / 3.5, smooth: 0.6), tone(low, dur, wave: :sine, vol: vol, slide_to: low / 2.0, decay: dur / 3))
      end
    end

    # Session finale, laid out on Scenes::Finale::Timeline; k stretches time.
    def self.finale(k = 1.0)
      tl = Scenes::Finale::Timeline
      s = Synth
      buf = []
      rng = Random.new(5)
      s.add(buf, 0, s.tone(120, tl::DROP * k, wave: :saw, vol: 0.14, slide_to: 700))
      s.add(buf, 0, s.riser(tl::DROP * k, vol: 0.35))
      s.add(buf, tl::DROP * k, s.boom(0.6, vol: 0.7))
      s.add(buf, tl::DROP * k, s.mix(*[523, 659, 784].map { |f| s.tone(f, 0.35, vol: 0.06, decay: 0.15) }))
      tl::ROWS.times do |i|
        st = (tl.row_start(i) + tl::SLIDE) * k
        n = (tl::COUNT * k / 0.03).floor
        n.times { |j| s.add(buf, st + j * 0.03, s.tone(900 + i * 70 + j * 15, 0.012, vol: 0.08, decay: 0.005)) }
        f = Scenes::Finale::NOTES[i]
        land = tl.row_land(i) * k
        s.add(buf, land, s.tone(f, 0.28, wave: :triangle, vol: 0.22, decay: 0.12))
        s.add(buf, land, s.tone(f * 2, 0.2, wave: :sine, vol: 0.06, decay: 0.08))
        s.add(buf, land, s.noise(0.03, vol: 0.12, decay: 0.01, rng: rng))
      end
      a = tl.score_start * k
      b = tl.score_land * k
      t = a
      i = 0
      while t < b - 0.01
        p = (t - a) / (b - a)
        s.add(buf, t, s.noise(0.03, vol: 0.12 + 0.4 * p, decay: 0.012, smooth: 0.3, rng: rng))
        t += 0.045 - 0.02 * p
        i += 1
      end
      s.add(buf, a, s.tone(180, b - a, wave: :saw, vol: 0.08, slide_to: 900))
      s.add(buf, b, s.boom(0.9, vol: 0.8, low: 70))
      s.add(buf, b, s.noise(1.1, vol: 0.22, decay: 0.45, smooth: 0.0, rng: rng))
      s.add(buf, b, s.mix(*[523, 659, 784, 1047].map { |f| s.tone(f, 0.6, wave: :square, vol: 0.05, decay: 0.25) }))
      r = tl.rank * k
      s.add(buf, r, s.mix(s.noise(0.05, vol: 0.5, decay: 0.015, rng: rng), s.tone(110, 0.25, wave: :sine, vol: 0.7, slide_to: 55, decay: 0.08)))
      fan = s.arp([392, 523, 659, 784], 0.09, vol: 0.13, decay: 0.07)
      s.add(buf, r + 0.06, fan)
      hold = r + 0.06 + fan.size.fdiv(RATE)
      [523, 659, 784, 1047].each do |f|
        s.add(buf, hold, s.tone(f, 1.3, vol: 0.05, vibrato: 0.012, decay: 0.7))
        s.add(buf, hold, s.tone(f / 2.0, 1.3, wave: :triangle, vol: 0.08, decay: 0.7))
      end
      s.add(buf, hold, s.tone(131, 1.2, wave: :triangle, vol: 0.18, decay: 0.6))
      10.times do |j|
        at = r + 0.2 + j * 0.13
        s.add(buf, at - 0.15, s.tone(500 + rng.rand(400), 0.15, wave: :sine, vol: 0.05, slide_to: 1600))
        s.add(buf, at, s.noise(0.14, vol: 0.4, decay: 0.05, smooth: 0.4, rng: rng))
        14.times { s.add(buf, at + 0.05 + rng.rand * 0.35, s.noise(0.006, vol: 0.18, decay: 0.003, rng: rng)) }
      end
      [buf, 0]
    end

    # name => [samples, impact offset in seconds]
    PATCHES = {
      key: -> { [Synth.tone(1400, 0.022, vol: 0.24, decay: 0.008), 0] },
      key_hot: -> { [Synth.tone(1900, 0.024, vol: 0.24, decay: 0.008), 0] },
      delete: -> { [Synth.mix(Synth.noise(0.04, vol: 0.12, decay: 0.012), Synth.tone(500, 0.05, vol: 0.08, slide_to: 180, wave: :triangle)), 0] },
      nice: -> { [Synth.seq(Synth.tone(988, 0.05, wave: :triangle, vol: 0.2, decay: 0.03), Synth.tone(1480, 0.09, wave: :triangle, vol: 0.2, decay: 0.05)), 0] },
      sealed: -> { [Synth.arp([659, 988, 1319], 0.05, wave: :triangle, vol: 0.18, decay: 0.04), 0] },
      lock: -> { [Synth.tone(1200, 0.09, vol: 0.12, slide_to: 2600, decay: 0.05), 0] },
      rewind: -> { [Synth.tone(1400, 0.16, vol: 0.12, slide_to: 350, wave: :triangle), 0] },
      charge: -> { [Synth.tone(300, 0.22, vol: 0.16, slide_to: 1200, wave: :saw), 0] },
      hit: -> { [Synth.seq(Synth.tone(440, 0.05, vol: 0.16, slide_to: 900), Synth.tone(1760, 0.12, wave: :triangle, vol: 0.2, decay: 0.05)), 0.05] },
      puff: -> { [Synth.seq(Synth.tone(900, 0.07, vol: 0.08, slide_to: 300, wave: :triangle), Synth.noise(0.3, vol: 0.45, decay: 0.12, smooth: 0.85)), 0.07] },
      stamp: -> { [Synth.mix(Synth.noise(0.05, vol: 0.5, decay: 0.015), Synth.tone(110, 0.2, wave: :sine, vol: 0.6, slide_to: 60, decay: 0.07)), 0] },
      counter: lambda {
        ticks = Synth.arp((0...14).map { |i| 400 * 2**(i / 7.0) }, 0.038, vol: 0.12, decay: 0.012)
        boom = Synth.mix(Synth.noise(0.45, vol: 0.45, decay: 0.14, smooth: 0.6), Synth.tone(90, 0.4, wave: :sine, vol: 0.6, slide_to: 45, decay: 0.15))
        [Synth.seq(ticks, boom), ticks.size.fdiv(RATE)]
      },
      banner: lambda {
        fan = Synth.arp([523, 659, 784], 0.07, vol: 0.16, decay: 0.05)
        hold = Synth.mix(*[1047, 1319, 1568].map { |f| Synth.tone(f, 0.35, vol: 0.09, vibrato: 0.01) })
        boom = Synth.noise(0.25, vol: 0.3, decay: 0.08, smooth: 0.5)
        [Synth.mix(Synth.seq(fan, hold), Synth.at(fan.size.fdiv(RATE), boom)), fan.size.fdiv(RATE)]
      },
      mega: lambda {
        fan = Synth.arp([523, 659, 784, 1047], 0.07, vol: 0.16, decay: 0.05)
        chord = Synth.mix(*[1047, 1319, 1568, 2093].map { |f| Synth.tone(f, 0.7, vol: 0.07, vibrato: 0.012) })
        blast = Synth.mix(Synth.noise(0.8, vol: 0.5, decay: 0.25, smooth: 0.55), Synth.tone(70, 0.6, wave: :sine, vol: 0.6, slide_to: 35, decay: 0.2))
        r = Random.new(3)
        pops = (0...6).map { |i| Synth.at(0.25 + i * 0.12, Synth.noise(0.12, vol: 0.25, decay: 0.04, rng: r)) }
        head = fan.size.fdiv(RATE)
        [Synth.mix(Synth.seq(fan, chord), Synth.at(head, blast), *pops.map { |p| Synth.at(head, p) }), head]
      },
      rain: -> { [Synth.mix(*(0...16).map { |i| Synth.at(i * 0.045, Synth.tone(600 + (i * 373) % 900, 0.03, vol: 0.22, decay: 0.012)) }), 0] },
      error: -> { [Synth.mix(Synth.tone(220, 0.28, wave: :saw, vol: 0.18, slide_to: 110), Synth.tone(233, 0.28, wave: :saw, vol: 0.14, slide_to: 116)), 0] },
      crack: -> { [Synth.mix(Synth.noise(0.12, vol: 0.55, decay: 0.03), Synth.tone(160, 0.25, wave: :saw, vol: 0.2, slide_to: 70)), 0] },
      snap: -> { [Synth.seq(Synth.tone(1800, 0.03, vol: 0.14), Synth.mix(Synth.noise(0.08, vol: 0.35, decay: 0.02), Synth.tone(300, 0.2, wave: :triangle, vol: 0.14, slide_to: 90))), 0.03] },
      interrupt: -> { [Synth.tone(900, 0.32, wave: :sine, vol: 0.25, slide_to: 90), 0] },
      intro: lambda {
        sweep = Synth.tone(200, 0.3, wave: :saw, vol: 0.12, slide_to: 1600)
        chord = Synth.mix(*[523, 659, 784, 1047].map { |f| Synth.tone(f, 0.6, vol: 0.07, vibrato: 0.01) })
        [Synth.seq(sweep, chord), 0.3]
      },
      result: -> { [Synth.seq(Synth.arp([784, 988, 1175, 1568], 0.08, wave: :triangle, vol: 0.2, decay: 0.06), Synth.tone(2093, 0.4, wave: :triangle, vol: 0.18, decay: 0.2)), 0] },
      finale: ->(k = 1.0) { Sound.finale(k) },
    }.freeze

    module_function

    def wav(samples)
      peak = samples.map(&:abs).max || 0.0
      k = peak > 0.9 ? 0.9 / peak : 1.0 # mixed patches would clip otherwise
      data = samples.map { |s| (s * k * 32_000).round }.pack("s<*")
      ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16, "data", data.bytesize].pack("a4Va4a4VvvVVvva4V") + data
    end

    def dir
      @dir ||= File.join(Dir.tmpdir, "dopairb-sfx-#{VERSION}-#{File.mtime(__FILE__).to_i}-#{Process.uid}")
    end

    # => [path, impact offset, length] (seconds)
    # Patches taking an argument are rendered per time stretch.
    def file(name, stretch = 1.0)
      patch = PATCHES.fetch(name)
      key = patch.arity.zero? ? name.to_s : "#{name}-#{stretch.round(2)}"
      @files ||= {}
      @files[key] ||= begin
        samples, impact = patch.arity.zero? ? patch.call : patch.call(stretch.round(2))
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "#{key}.wav")
        unless File.exist?(path)
          tmp = "#{path}.#{Process.pid}"
          File.binwrite(tmp, wav(samples))
          File.rename(tmp, path)
        end
        [path, impact, samples.size.fdiv(RATE)]
      end
    end

    # Seconds from start until the sound has finished, measured from its impact.
    def tail(name, stretch = 1.0)
      _, impact, len = file(name, stretch)
      len - impact
    end

    def which(cmd)
      ENV["PATH"].to_s.split(File::PATH_SEPARATOR).map { |d| File.join(d, cmd) }.find { |p| File.executable?(p) && !File.directory?(p) }
    end

    def wsl?
      @wsl = File.read("/proc/version").match?(/microsoft/i) if @wsl.nil?
      @wsl
    rescue StandardError
      @wsl = false
    end

    # [kind, argv-prefix] or nil
    def backend
      return @backend if defined?(@backend)
      @backend =
        if (p = which("paplay")) && (ENV["PULSE_SERVER"] || !wsl? || File.exist?("/mnt/wslg/PulseServer"))
          [:fast, [p]]
        elsif (p = which("afplay"))
          [:fast, [p]]
        elsif (p = which("aplay"))
          [:fast, [p, "-q"]]
        elsif wsl? && (p = which("powershell.exe")) && which("wslpath")
          [:slow, [p, "-NoProfile", "-NonInteractive", "-Command"]]
        end
    end

    def reset_backend
      remove_instance_variable(:@backend) if defined?(@backend)
    end

    def available? = !backend.nil?

    # Per-keystroke sounds only make sense with a low-latency player.
    def fast? = backend&.first == :fast

    @last = {}
    @children = []

    # Start playing so that the sound's impact lands `delay` seconds from now.
    def play(name, delay: 0.0, stretch: 1.0)
      kind, argv = backend
      return false unless kind
      return false if kind == :slow && %i[key key_hot delete].include?(name)
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return false if @last[name] && now - @last[name] < 0.04
      @children.reject! { |pid| Process.waitpid(pid, Process::WNOHANG) rescue true }
      return false if @children.size >= 4
      @last[name] = now
      started = now
      Thread.new do
        Thread.current.report_on_exception = false
        path, impact = file(name, stretch)
        cmd = if kind == :slow
                win = OutputTap.quietly { IO.popen(["wslpath", "-w", path], &:read) }.strip
                argv + ["(New-Object Media.SoundPlayer '#{win}').PlaySync()"]
              else
                argv + [path]
              end
        spent = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        wait = delay - impact - spent - (kind == :slow ? 0.3 : 0.03)
        sleep wait if wait > 0.01
        pid = OutputTap.quietly { Process.spawn(*cmd, in: File::NULL, out: File::NULL, err: File::NULL, pgroup: true) }
        @children << pid
      rescue StandardError => e
        Dopairb.debug(e)
      end
      true
    rescue StandardError => e
      Dopairb.debug(e)
      false
    end

    # Synthesize everything in the background so the first sound is not late.
    def warm_up(stretch = 1.0)
      return unless available?
      Thread.new do
        Thread.current.report_on_exception = false
        PATCHES.each_key { |n| file(n, stretch) }
      end
    end
  end
end
