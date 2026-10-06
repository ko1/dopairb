# frozen_string_literal: true

require "pty"
require "tmpdir"
require "fileutils"
require "io/console"
require_relative "vt"

# Runs a command on a pseudo terminal and mirrors its output into a VT model.
class PTYDriver
  attr_reader :vt, :raw, :pid

  ROOT = File.expand_path("../..", __dir__)

  def self.dopairb(*args, rows: 24, cols: 80, env: {})
    cmd = [RbConfig.ruby, "-I#{ROOT}/lib", "#{ROOT}/exe/dopairb", *args]
    new(cmd, rows: rows, cols: cols, env: env)
  end

  def initialize(cmd, rows: 24, cols: 80, env: {})
    @master, slave = PTY.open
    slave.winsize = [rows, cols]
    base = { "TERM" => "xterm-256color", "COLORTERM" => "truecolor", "LANG" => "C.UTF-8", "HOME" => ENV["HOME"],
             "NO_COLOR" => nil, "DOPAIRB" => nil, "DOPAIRB_PROFILE" => "off", "LINES" => nil, "COLUMNS" => nil }
    # an empty rc in a private dir keeps the user's ~/.irbrc and history out
    @dir = Dir.mktmpdir("dopairb-test")
    base["IRBRC"] = File.join(@dir, "irbrc")
    File.write(base["IRBRC"], "")
    # setsid -c makes the pty our controlling terminal so ^C raises SIGINT
    @pid = Process.spawn(base.merge(env), "setsid", "-c", *cmd, in: slave, out: slave, err: slave)
    slave.close
    @mutex = Mutex.new
    @raw = +"".b
    @vt = VT.new(rows, cols, reply: ->(s) { @master.write(s) rescue nil })
    @reader = Thread.new do
      loop do
        data = @master.readpartial(65_536)
        @mutex.synchronize do
          @raw << data
          @vt.feed(data)
        end
      end
    rescue EOFError, Errno::EIO, IOError
      nil
    end
  end

  def type(str, delay: 0.02)
    str.each_char do |c|
      @master.write(c)
      sleep delay
    end
  end

  def send_keys(str)
    @master.write(str)
  end

  def text = @mutex.synchronize { @vt.text }
  def all_text = @mutex.synchronize { @vt.all_text }
  def lines = @mutex.synchronize { @vt.lines }
  def raw_output = @mutex.synchronize { @raw.dup }

  def wait_for(pattern, timeout: 10, all: false)
    deadline = Time.now + timeout
    loop do
      t = all ? all_text : text
      return t if pattern === t
      raise "timeout waiting for #{pattern.inspect}\n---- screen ----\n#{text}" if Time.now > deadline
      sleep 0.05
    end
  end

  # Wait until the screen stops changing for `quiet` seconds.
  def settle(quiet: 0.6, timeout: 15)
    deadline = Time.now + timeout
    last = raw_output.bytesize
    stable_since = Time.now
    loop do
      sleep 0.05
      now = raw_output.bytesize
      if now != last
        last = now
        stable_since = Time.now
      elsif Time.now - stable_since >= quiet
        return text
      end
      raise "screen never settled\n#{text}" if Time.now > deadline
    end
  end

  def alive?
    Process.waitpid(@pid, Process::WNOHANG).nil?
  rescue Errno::ECHILD
    false
  end

  def wait_exit(timeout: 10)
    deadline = Time.now + timeout
    while Time.now < deadline
      r = Process.waitpid(@pid, Process::WNOHANG)
      return $?.exitstatus if r
      sleep 0.05
    end
    nil
  end

  def close
    Process.kill(:KILL, @pid) rescue nil
    Process.waitpid(@pid) rescue nil
    @master.close rescue nil
    @reader.join(1)
    FileUtils.rm_rf(@dir) if @dir
  end
end
