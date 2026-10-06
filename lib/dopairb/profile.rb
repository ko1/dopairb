# frozen_string_literal: true

require "json"
require "date"
require "fileutils"

module Dopairb
  # What survives between sessions: lifetime XP (= total score), best score,
  # best combo, the day streak and the collected bonus art. One small JSON
  # file under $XDG_STATE_HOME (~/.local/state/dopairb/profile.json), or
  # $DOPAIRB_PROFILE. DOPAIRB_PROFILE=off keeps nothing.
  class Profile
    FIELDS = %i[xp best_score best_combo sessions streak last_day gallery].freeze

    attr_accessor(*FIELDS)
    attr_reader :path

    def self.default_path
      env = ENV["DOPAIRB_PROFILE"]
      return nil if env && %w[off 0 none].include?(env.downcase)
      return env if env && !env.empty?
      base = ENV["XDG_STATE_HOME"].to_s.empty? ? File.join(Dir.home, ".local", "state") : ENV["XDG_STATE_HOME"]
      File.join(base, "dopairb", "profile.json")
    rescue ArgumentError # no home directory
      nil
    end

    def self.load(path = default_path)
      prof = new(path)
      return prof unless path && File.exist?(path)
      data = JSON.parse(File.read(path), symbolize_names: true)
      prof.xp = data[:xp].to_i
      prof.best_score = data[:best_score].to_i
      prof.best_combo = data[:best_combo].to_i
      prof.sessions = data[:sessions].to_i
      prof.streak = data[:streak].to_i
      prof.last_day = data[:last_day]
      prof.gallery = Array(data[:gallery]).map(&:to_sym) & Gallery.ids
      prof
    rescue SystemCallError, JSON::ParserError => e
      Dopairb.debug(e)
      new(path)
    end

    def initialize(path = nil)
      @path = path
      @xp = 0
      @best_score = 0
      @best_combo = 0
      @sessions = 0
      @streak = 0
      @last_day = nil
      @gallery = []
    end

    def level = Game.level_for(@xp)
    def persistent? = !@path.nil?

    # Count today toward the day streak. => true when the streak grew today.
    def visit(today = Date.today)
      day = today.iso8601
      return false if @last_day == day
      yesterday = (today - 1).iso8601
      @streak = @last_day == yesterday ? @streak + 1 : 1
      @last_day = day
      true
    end

    def collect(id)
      return false if @gallery.include?(id)
      @gallery << id
      true
    end

    # Fold a finished session in. Another dopairb may have saved meanwhile,
    # so the file is re-read first and only this session's numbers are added.
    def finish(stats, collected: [])
      disk = persistent? ? Profile.load(@path) : self
      disk.xp += stats[:score].to_i
      disk.best_score = [disk.best_score, stats[:score].to_i].max
      disk.best_combo = [disk.best_combo, stats[:max_combo].to_i].max
      disk.sessions += 1
      if @last_day.to_s > disk.last_day.to_s
        disk.last_day = @last_day
        disk.streak = @streak
      end
      collected.each { |id| disk.collect(id) }
      disk.save
      disk
    end

    def to_h = FIELDS.to_h { |k| [k, public_send(k)] }

    def save
      return false unless @path
      FileUtils.mkdir_p(File.dirname(@path))
      tmp = "#{@path}.#{Process.pid}.tmp"
      File.write(tmp, JSON.pretty_generate(to_h) + "\n")
      File.rename(tmp, @path)
      true
    rescue SystemCallError => e
      Dopairb.debug(e)
      false
    end
  end
end
