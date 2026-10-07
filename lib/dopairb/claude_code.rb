# frozen_string_literal: true

require "json"
require "fileutils"

module Dopairb
  # dopacc: the dopairb show on top of Claude Code, driven by its hooks.
  #
  # Claude Code owns the terminal, so a hook finds Claude Code's tty by
  # walking up the process tree, draws a full-screen banner on it and then
  # makes Claude Code lay its screen out again by wiggling the window size.
  # Everything here is cheap to load; the effects (`require "dopairb"`) are
  # only loaded when something is actually drawn or played.
  module ClaudeCode
    MODES = %w[on calm off].freeze
    HOOK_EVENTS = %w[PostToolUse PostToolUseFailure Stop].freeze
    JACKPOT_CHANCE = 1 / 64.0
    FEVER_COMBO = 10
    DONE = ["MISSION COMPLETE!", "DONE!", "NICE WORK!", "GG!", "CLEAR!"].freeze

    # Shared progress in a JSON file, updated under an exclusive lock
    # because hooks of parallel tool calls run at the same time.
    module State
      DEFAULTS = { "mode" => "on", "session" => nil, "combo" => 0, "best" => 0, "score" => 0,
                   "tools" => 0, "turn_tools" => 0, "turn_score" => 0 }.freeze

      module_function

      def path
        ENV["DOPACC_STATE"] || File.join(ENV["XDG_STATE_HOME"] || File.expand_path("~/.local/state"), "dopairb", "dopacc.json")
      end

      def read
        DEFAULTS.merge(JSON.parse(File.read(path)))
      rescue SystemCallError, JSON::ParserError
        DEFAULTS.dup
      end

      # Yields the state; whatever the block changes is written back.
      def update
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, File::RDWR | File::CREAT, 0o644) do |f|
          f.flock(File::LOCK_EX)
          s = DEFAULTS.merge((JSON.parse(f.read) rescue {}))
          result = yield s
          f.rewind
          f.truncate(0)
          f.write(JSON.pretty_generate(s))
          result
        end
      end
    end

    # One hook call: hook JSON in, a list of effects out.
    module Hook
      module_function

      def run(input, rng: nil)
        ev = (JSON.parse(input) rescue {})
        return [] if %w[off 0 false].include?(ENV["DOPACC"].to_s)
        mode = nil
        plan = State.update do |s|
          mode = s["mode"]
          next [] if mode == "off"
          rng ||= rng_for(s["tools"])
          if s["session"] != ev["session_id"]
            s.merge!("session" => ev["session_id"], "combo" => 0, "turn_tools" => 0, "turn_score" => 0)
          end
          case ev["hook_event_name"]
          when "PostToolUse" then success(s, rng)
          when "PostToolUseFailure" then failure(s)
          when "Stop" then stop(s, rng)
          else []
          end
        end
        # calm: sounds only, never take the screen
        plan = plan.map { |e| e[:show] ? { sound: e[:sound] } : e } if mode == "calm"
        plan
      end

      # DOPACC_SEED makes the luck repeatable (for recordings), call by call.
      def rng_for(tools)
        ENV["DOPACC_SEED"] ? Random.new(ENV["DOPACC_SEED"].to_i * 1000 + tools) : Random.new
      end

      def success(s, rng)
        s["combo"] += 1
        s["tools"] += 1
        s["turn_tools"] += 1
        combo = s["combo"]
        new_best = combo > s["best"]
        s["best"] = combo if new_best
        gain = (10 + combo) * (combo >= FEVER_COMBO ? 2 : 1)
        jackpot = rng.rand < JACKPOT_CHANCE
        gain *= 16 if jackpot
        s["score"] += gain
        s["turn_score"] += gain
        if jackpot
          [{ show: "JACKPOT!!", sub: "+#{commas(gain)} (x16)", palette: :GOLD, sound: :jackpot }]
        elsif combo >= 8 && (combo & (combo - 1)).zero?
          [{ show: "COMBO #{combo}!", sub: new_best ? "ALL-TIME BEST!" : "#{combo}-HIT CHAIN", palette: :FIRE, sound: :mega }]
        else
          [{ sound: combo >= FEVER_COMBO ? :hit : :nice }]
        end
      end

      def failure(s)
        broken = s["combo"] >= 4
        s["combo"] = 0
        [{ sound: broken ? :crack : :error }]
      end

      def stop(s, rng)
        tools = s["turn_tools"]
        score = s["turn_score"]
        s["turn_tools"] = 0
        s["turn_score"] = 0
        # a plain answer (no tools) only gets a jingle
        return [{ sound: :result }] if tools.zero?
        [{ show: DONE.sample(random: rng), sub: "#{tools} TOOLS  +#{commas(score)}  COMBO #{s["combo"]}  BEST #{s["best"]}",
           palette: :GOLD, sound: :mega }]
      end

      def commas(n) = n.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    # Drawing on Claude Code's terminal from a hook process.
    module Screen
      module_function

      # => [pid, "/dev/pts/N"] of the nearest ancestor that owns a terminal
      def find(pid = Process.ppid)
        while pid && pid > 1
          tty = tty_of(pid)
          return [pid, tty] if tty
          pid = parent_of(pid)
        end
        nil
      end

      def tty_of(pid)
        if File.directory?("/proc/#{pid}/fd")
          [1, 2, 0].each do |fd|
            t = (File.readlink("/proc/#{pid}/fd/#{fd}") rescue nil)
            return t if t&.start_with?("/dev/pts/", "/dev/tty")
          end
          nil
        else
          t = `ps -o tty= -p #{pid.to_i} 2>/dev/null`.strip
          t.empty? || t.start_with?("?", "-") ? nil : "/dev/#{t.delete_prefix("/dev/")}"
        end
      end

      def parent_of(pid)
        if File.exist?("/proc/#{pid}/stat")
          File.read("/proc/#{pid}/stat")[/\) \S (\d+)/, 1]&.to_i
        else
          `ps -o ppid= -p #{pid.to_i} 2>/dev/null`.strip.then { |s| s.empty? ? nil : s.to_i }
        end
      rescue SystemCallError
        nil
      end

      # Claude Code's fullscreen TUI already lives on the alternate screen;
      # the classic one draws on the main screen.
      def fullscreen?(cwd = Dir.pwd)
        return false if truthy?(ENV["CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN"])
        return true if truthy?(ENV["CLAUDE_CODE_NO_FLICKER"])
        tui = nil
        [File.expand_path("~/.claude/settings.json"), File.join(cwd, ".claude/settings.json"),
         File.join(cwd, ".claude/settings.local.json")].each do |f|
          v = (JSON.parse(File.read(f))["tui"] rescue nil)
          tui = v if v
        end
        tui == "fullscreen"
      end

      def truthy?(v) = !v.nil? && !%w[0 false no off].include?(v.to_s.downcase) && !v.empty?

      def show(text, sub: nil, palette: :GOLD, sound: :mega, secs: 2.0, cwd: Dir.pwd)
        _pid, path = find
        return false unless path
        require_relative "../dopairb"
        # hooks of parallel tool calls take turns on the screen
        FileUtils.mkdir_p(File.dirname(State.path))
        lock = File.open("#{State.path}.lock", File::RDWR | File::CREAT, 0o644)
        lock.flock(File::LOCK_EX)
        tty = File.open(path, "r+")
        tty.sync = true
        Term.out = tty
        Term.input = tty
        rows, cols = tty.winsize
        swap = !fullscreen?(cwd)
        play(sound) if sound
        ctx = Ctx.new(w: cols - 1, rows: rows, depth: Term.depth(Config.new), config: Config.new, rng: Random.new,
                      input: nil, pre: 0.0, compact: false)
        banner = Scenes::Banner.new(ctx, nil, text: text, sub: sub, palette: Color.const_get(palette),
                                              mega: true, rainbow: true, alt: true)
        tty.write(swap ? "\e[?1049h\e[?25l\e[2J" : "\e7\e[?25l\e[2J")
        t0 = now
        while (t = now - t0) < secs
          c = Canvas.new(cols - 1, rows)
          banner.draw(c, t)
          lines = c.render(ctx.depth, shake: banner.shake(t))
          tty.write("\e[H" + lines.map { |l| "#{l}\e[0m\e[K" }.join("\r\n"))
          sleep [1 / 30.0 - (now - t0 - t), 0].max
        end
        if swap
          tty.write("\e[0m\e[?1049l\e[?25h")
        else
          # A real size change makes the TUI lay everything out again.
          tty.write("\e[0m\e[2J\e8")
          tty.winsize = [rows, cols - 1]
          sleep 0.08
          tty.winsize = [rows, cols]
        end
        true
      ensure
        tty&.close
        lock&.close
      end

      # Players outlive the hook process, which exits right away.
      def play(name)
        require_relative "../dopairb"
        kind, argv = Sound.backend
        return false unless kind
        return Sound.log_play(argv[0], name, 0.0, 1.0) if kind == :log # recordings
        path, = Sound.file(name)
        cmd = if kind == :slow
                win = IO.popen(["wslpath", "-w", path], err: File::NULL, &:read).strip
                argv + ["(New-Object Media.SoundPlayer '#{win}').PlaySync()"]
              else
                argv + [path]
              end
        Process.detach(Process.spawn(*cmd, in: File::NULL, out: File::NULL, err: File::NULL, pgroup: true))
        true
      end

      def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # `dopacc install`: hooks (and a status line) in Claude Code's settings.
    module Installer
      module_function

      def command
        bin = File.join(Gem.bindir, "dopacc") if defined?(Gem)
        exe = if bin && File.exist?(bin) then bin
              elsif File.basename($PROGRAM_NAME) == "dopacc" then File.expand_path($PROGRAM_NAME)
              else "dopacc"
              end
        exe.include?(" ") ? "\"#{exe}\"" : exe
      end

      def ours?(hook) = hook["command"].to_s.match?(/dopacc(\"?)? hook\z/)

      def install(settings_path, statusline: true)
        s = load(settings_path)
        strip!(s)
        hooks = (s["hooks"] ||= {})
        HOOK_EVENTS.each do |ev|
          (hooks[ev] ||= []) << { "matcher" => "", "hooks" => [{ "type" => "command", "command" => "#{command} hook", "timeout" => 15 }] }
        end
        notes = []
        if statusline
          if s["statusLine"].nil? || s["statusLine"]["command"].to_s.include?("dopacc")
            s["statusLine"] = { "type" => "command", "command" => "#{command} statusline" }
          else
            notes << "kept your statusLine; `dopacc statusline` prints the COMBO line if you want to add it"
          end
        end
        save(settings_path, s)
        notes
      end

      def uninstall(settings_path)
        s = load(settings_path)
        strip!(s)
        s.delete("statusLine") if s["statusLine"].to_h["command"].to_s.include?("dopacc")
        save(settings_path, s)
      end

      def installed?(settings_path)
        load(settings_path).fetch("hooks", {}).values.flatten.any? { |m| m.fetch("hooks", []).any? { |h| ours?(h) } }
      end

      def strip!(s)
        hooks = s["hooks"] or return
        hooks.each_value do |matchers|
          matchers.each { |m| m["hooks"]&.reject! { |h| ours?(h) } }
          matchers.reject! { |m| m["hooks"]&.empty? }
        end
        hooks.reject! { |_, v| v.empty? }
        s.delete("hooks") if hooks.empty?
      end

      def load(path)
        File.exist?(path) ? JSON.parse(File.read(path)) : {}
      end

      def save(path, s)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.cp(path, "#{path}.bak") if File.exist?(path)
        tmp = "#{path}.#{Process.pid}.tmp"
        File.write(tmp, JSON.pretty_generate(s) + "\n")
        File.rename(tmp, path)
      end
    end

    # `dopacc statusline`: one line, no effects library, fast.
    def self.statusline(s = State.read)
      return "\e[2mdopacc off\e[0m" if s["mode"] == "off"
      combo = s["combo"]
      fever = combo >= FEVER_COMBO
      head = fever ? rainbow("FEVER!") + " " : ""
      "#{head}\e[1;38;2;255;170;60mCOMBO #{combo}\e[0m  \e[38;2;255;220;120mSCORE #{Hook.commas(s["score"])}\e[0m  " \
        "\e[2mBEST #{s["best"]}#{s["mode"] == "calm" ? "  (calm)" : ""}\e[0m"
    end

    def self.rainbow(str)
      t = Time.now.to_f * 2
      str.chars.each_with_index.map do |ch, i|
        h = (t + i * 0.15) % 1.0
        r, g, b = [0, 2, 4].map { |k| (Math.sin((h + k / 6.0) * 2 * Math::PI) * 127 + 128).round }
        "\e[1;38;2;#{r};#{g};#{b}m#{ch}"
      end.join + "\e[0m"
    end
  end
end
