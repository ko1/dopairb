# Drive dopairb on a PTY with a scripted session and record the output.
# usage: ruby record.rb OUTDIR
require "pty"
require "json"
require "date"
require "fileutils"
ROOT = File.expand_path("../..", __dir__)
require "#{ROOT}/test/support/vt"
load File.join(__dir__, "scenario.rb")

out = File.expand_path(ARGV[0] || "out", __dir__)
FileUtils.mkdir_p(out)
ROWS = 36
COLS = 120
prof = File.join(out, "profile.json")
File.write(prof, JSON.generate(xp: 10_400, best_score: 5_000, best_combo: 6, sessions: 3, streak: 2,
                               last_day: (Date.today - 1).iso8601, gallery: ["red_fuji"]))
sndlog = File.join(out, "sound.log")
File.write(sndlog, "")
rc = File.join(out, "irbrc")
File.write(rc, "")
env = { "TERM" => "xterm-256color", "COLORTERM" => "truecolor", "LANG" => "C.UTF-8", "IRBRC" => rc,
        "DOPAIRB_PROFILE" => prof, "DOPAIRB_SEED" => "455616", "DOPAIRB_SOUND_LOG" => sndlog, "NO_COLOR" => nil,
        "DOPAIRB" => nil, "LINES" => nil, "COLUMNS" => nil, "HOME" => out }
master, slave = PTY.open
slave.winsize = [ROWS, COLS]
cmd = [RbConfig.ruby, "-I#{ROOT}/lib", "#{ROOT}/exe/dopairb", "--max", "--sound"]
pid = Process.spawn(env, "setsid", "-c", *cmd, in: slave, out: slave, err: slave)
slave.close
chunks = []
last_data = Time.now
t0 = Process.clock_gettime(Process::CLOCK_REALTIME)
vt = VT.new(ROWS, COLS, reply: ->(s) { master.write(s) rescue nil })
mutex = Mutex.new
reader = Thread.new do
  loop do
    data = master.readpartial(65_536)
    mutex.synchronize do
      chunks << [Process.clock_gettime(Process::CLOCK_REALTIME) - t0, data]
      vt.feed(data)
      last_data = Time.now
    end
  end
rescue EOFError, Errno::EIO, IOError
  nil
end

def idle_wait(min, quiet, max = 15)
  start = Time.now
  sleep min
  sleep 0.05 until Time.now - $last.call > quiet || Time.now - start > max
end
$last = -> { mutex.synchronize { last_data } }

def type(m, str, speed)
  str.each_char do |c|
    m.write(c)
    sleep speed * (0.8 + rand * 0.4)
  end
end

srand(1)
idle_wait(3.0, 0.8, 20) # intro (and loading screen)
sleep 0.6
SCENARIO.each_with_index do |(code, _), i|
  fast = code.size > 30
  type(master, code, fast ? 0.05 : 0.085)
  sleep fast ? 0.15 : 0.35
  master.write("\r")
  prompt = format("(main):%03d> ", i + 2)
  start = Time.now
  sleep 0.05 until mutex.synchronize { vt.text.include?(prompt) } || Time.now - start > 20
  sleep 0.9
end
type(master, "exit", 0.1)
sleep 0.3
master.write("\r")
Process.wait(pid)
reader.join(2)
dur = Process.clock_gettime(Process::CLOCK_REALTIME) - t0
File.binwrite(File.join(out, "session.raw"), Marshal.dump({ t0: t0, rows: ROWS, cols: COLS, chunks: chunks, duration: dur }))
puts "recorded #{chunks.size} chunks, #{dur.round(1)}s"
puts File.read(prof)
