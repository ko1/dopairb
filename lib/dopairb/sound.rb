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

    # name => [samples, impact offset in seconds]. Shareable so a Ractor can render them.
    PATCHES = Ractor.make_shareable({
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
      bits: lambda {
        up = Synth.arp([523, 659, 784, 1047, 1319, 1568, 2093], 0.035, vol: 0.13, decay: 0.03)
        [Synth.seq(up, Synth.tone(2093, 0.18, vol: 0.1, vibrato: 0.02, decay: 0.08)), 0]
      },
      crit: lambda {
        shing = Synth.tone(2400, 0.1, wave: :saw, vol: 0.12, slide_to: 5200, decay: 0.05)
        thud = Synth.mix(Synth.noise(0.12, vol: 0.55, decay: 0.03), Synth.tone(140, 0.25, wave: :sine, vol: 0.7, slide_to: 60, decay: 0.08))
        sting = Synth.mix(*[880, 1109, 1319].map { |f| Synth.tone(f, 0.3, wave: :square, vol: 0.06, decay: 0.12) })
        [Synth.mix(shing, Synth.at(0.1, thud), Synth.at(0.12, sting)), 0.1]
      },
      jackpot: lambda {
        r = Random.new(9)
        buf = []
        t = 0.0
        while t < 0.95
          Synth.add(buf, t, Synth.tone(700 + r.rand(500), 0.02, vol: 0.1, decay: 0.008))
          t += 0.045
        end
        [0.45, 0.7, 0.95].each_with_index do |at, i|
          Synth.add(buf, at, Synth.mix(Synth.noise(0.05, vol: 0.4, decay: 0.015, rng: r), Synth.tone(160 + i * 40, 0.15, wave: :sine, vol: 0.5, slide_to: 80, decay: 0.05)))
          Synth.add(buf, at, Synth.tone([784, 988, 1175][i], 0.12, wave: :triangle, vol: 0.18, decay: 0.06))
        end
        Synth.add(buf, 0.95, Synth.boom(0.8, vol: 0.6, low: 75))
        Synth.add(buf, 1.0, Synth.arp([1047, 1319, 1568, 2093, 1568, 2093, 2637], 0.07, vol: 0.12, decay: 0.05))
        40.times { Synth.add(buf, 1.0 + r.rand * 1.2, Synth.tone(2600 + r.rand(1800), 0.06, wave: :sine, vol: 0.08, decay: 0.02)) }
        [buf, 0.95]
      },
      levelup: lambda {
        buf = []
        Synth.add(buf, 0, Synth.tone(150, 0.22, wave: :saw, vol: 0.12, slide_to: 900))
        Synth.add(buf, 0.22, Synth.boom(0.7, vol: 0.6))
        fan = Synth.arp([523, 659, 784, 1047, 784, 1047, 1319, 1568], 0.06, vol: 0.13, decay: 0.05)
        Synth.add(buf, 0.24, fan)
        [1047, 1319, 1568, 2093].each { |f| Synth.add(buf, 0.72, Synth.tone(f, 0.5, vol: 0.06, vibrato: 0.015, decay: 0.3)) }
        # the unveiling: a gong and a shimmering chord
        Synth.add(buf, 1.0, Synth.tone(98, 1.6, wave: :sine, vol: 0.45, decay: 0.7, vibrato: 0.004))
        Synth.add(buf, 1.0, Synth.tone(196, 1.2, wave: :triangle, vol: 0.12, decay: 0.5))
        Synth.add(buf, 1.45, Synth.noise(0.5, vol: 0.25, decay: 0.15, smooth: 0.5))
        [523, 659, 784, 1047, 1319].each_with_index do |f, i|
          Synth.add(buf, 1.45 + i * 0.05, Synth.tone(f, 1.4, vol: 0.05, vibrato: 0.01, decay: 0.6))
        end
        r = Random.new(4)
        16.times { Synth.add(buf, 1.6 + r.rand * 1.4, Synth.tone(3000 + r.rand(2000), 0.05, wave: :sine, vol: 0.06, decay: 0.015)) }
        [buf, 0.22]
      },
      finale: ->(k = 1.0) { Sound.finale(k) },
    })

    # The startup sound first: the loading screen waits for it.
    ORDER = [:intro, *(PATCHES.keys - [:intro])].freeze

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
    # Patches taking an argument are rendered per time stretch. Rendered
    # sounds are reused across sessions; the .meta file is written last.
    def file(name, stretch = 1.0)
      key = key_for(name, stretch)
      @files ||= {}
      @files[key] ||= cached(key) || render(name, stretch, key)
    end

    def key_for(name, stretch)
      PATCHES.fetch(name).arity.zero? ? name.to_s : "#{name}-#{stretch.round(2)}"
    end

    def cached(key)
      path = File.join(dir, "#{key}.wav")
      impact, len = File.read("#{path}.meta").split.map(&:to_f)
      [path, impact, len] if len && File.exist?(path)
    rescue SystemCallError
      nil
    end

    # Pure (no module state) so it can run inside a Ractor.
    def render(name, stretch, key, dir = self.dir)
      patch = PATCHES.fetch(name)
      samples, impact = patch.arity.zero? ? patch.call : patch.call(stretch.round(2))
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      path = File.join(dir, "#{key}.wav")
      len = samples.size.fdiv(RATE)
      atomic_write(path, wav(samples))
      atomic_write("#{path}.meta", "#{impact} #{len}\n")
      [path, impact, len]
    end

    def atomic_write(path, data)
      tmp = "#{path}.#{Process.pid}.tmp"
      File.binwrite(tmp, data)
      File.rename(tmp, path)
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
        if (log = ENV["DOPAIRB_SOUND_LOG"]) && !log.empty?
          [:log, [log]] # recordings: write "<wall clock of impact> <wav>" lines instead of playing
        elsif (p = which("paplay")) && (ENV["PULSE_SERVER"] || !wsl? || File.exist?("/mnt/wslg/PulseServer"))
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
    def fast? = %i[fast log].include?(backend&.first)

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
      return log_play(argv[0], name, delay, stretch) if kind == :log
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

    def log_play(log, name, delay, stretch)
      at = Process.clock_gettime(Process::CLOCK_REALTIME) + delay
      path, impact = file(name, stretch)
      File.open(log, "a") { |f| f.puts format("%.4f %s", at - impact, path) }
      true
    end

    def ready?(name, stretch = 1.0) = !cached(key_for(name, stretch)).nil?

    # Render every missing sound in the background, the startup sound first.
    # A Ractor runs the synthesis in parallel with the REPL (no GVL contention,
    # so typing stays smooth); without Ractor support, a thread does it.
    def warm_up(stretch = 1.0)
      return unless available?
      return @warming if @warming&.alive?
      missing = ORDER.reject { |n| ready?(n, stretch) }
      return if missing.empty?
      FileUtils.mkdir_p(dir)
      @warming = start_ractor(missing, stretch) || Thread.new do
        Thread.current.report_on_exception = false
        missing.each { |n| file(n, stretch) }
      end
    rescue StandardError => e
      Dopairb.debug(e)
      nil
    end

    # => a Thread that finishes when the Ractor has rendered everything, or nil
    def start_ractor(names, stretch)
      return nil unless defined?(Ractor)
      args = Ractor.make_shareable([dir.dup, names.map { |n| [n, key_for(n, stretch)] }, stretch.round(2)])
      prev = Warning[:experimental]
      Warning[:experimental] = false # "Ractor API is experimental" must not reach the user
      r = begin
        Ractor.new(args) do |(d, jobs, k)|
          jobs.each { |n, key| Sound.render(n, k, key, d) }
          :done
        rescue Exception # rubocop:disable Lint/RescueException
          :failed
        end
      ensure
        Warning[:experimental] = prev
      end
      Thread.new do
        Thread.current.report_on_exception = false
        r.value
      end
    rescue StandardError => e
      Dopairb.debug(e)
      nil
    end
  end
end
