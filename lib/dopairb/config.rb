# frozen_string_literal: true

module Dopairb
  # User-tunable knobs. See `dopa help` or README for the meaning of each.
  class Config
    INTENSITIES = %i[off low normal max].freeze
    FLASHES = %i[off soft full].freeze
    COLORS = %i[auto truecolor 256 16 none].freeze
    TRAILS = %i[none big all].freeze
    SOUNDS = %i[off bell sfx].freeze

    DESCRIPTIONS = {
      intensity: "off / low / normal / max  -- overall amount of effects",
      motion: "on / off  -- animations (off = static badges only)",
      flash: "off / soft / full  -- soft = region only, full = whole screen",
      sound: "off / bell / sfx  -- sfx = synthesized effects (paplay/aplay/afplay/WSL), bell = terminal bell",
      hud: "on / off  -- COMBO / SCORE / CHARGE next to the prompt",
      duration: "float multiplier for every effect length (e.g. 0.5, 2)",
      color: "auto / truecolor / 256 / 16 / none",
      trail: "none / big / all  -- which effects leave a one-line badge",
      charge: "seconds (max 0.3) of wind-up before a fast result lands; 0 disables",
      intro: "on / off  -- title animation at startup",
      keys: "on / off  -- per-keystroke effects while typing",
      binding_irb: "on / off  -- effects in sessions opened by binding.irb too",
    }.freeze

    attr_reader :intensity, :motion, :flash, :sound, :hud, :duration, :color, :trail, :charge, :intro, :keys, :binding_irb

    def initialize
      @intensity = :normal
      @motion = true
      @flash = :soft
      @sound = :off
      @hud = true
      @duration = 1.0
      @color = :auto
      @trail = :big
      @charge = 0.12
      @intro = true
      @keys = true
      @binding_irb = true
    end

    def level
      INTENSITIES.index(@intensity)
    end

    def off? = @intensity == :off
    def max? = @intensity == :max

    def set(name, value)
      name = name.to_s.strip.downcase.tr("-", "_").to_sym
      case name
      when :intensity then @intensity = enum(value, INTENSITIES, name)
      when :flash
        v = bool_or_nil(value)
        @flash = v.nil? ? enum(value, FLASHES, name) : (v ? :soft : :off)
      when :color
        v = bool_or_nil(value)
        @color = v.nil? ? enum(value, COLORS, name) : (v ? :auto : :none)
      when :trail then @trail = enum(value, TRAILS, name)
      when :sound
        v = bool_or_nil(value)
        @sound = v.nil? ? enum(value, SOUNDS, name) : (v ? :sfx : :off)
      when :motion, :hud, :intro, :keys, :binding_irb
        v = bool_or_nil(value)
        raise ArgumentError, "#{name} expects on/off, got #{value.inspect}" if v.nil?
        instance_variable_set(:"@#{name}", v)
      when :duration
        f = Float(value.to_s)
        raise ArgumentError, "duration must be in 0.1..5" unless (0.1..5).cover?(f)
        @duration = f
      when :charge
        f = Float(value.to_s)
        raise ArgumentError, "charge must be in 0..0.3 (seconds)" unless (0..0.3).cover?(f)
        @charge = f
      else
        raise ArgumentError, "unknown setting #{name.inspect} (known: #{DESCRIPTIONS.keys.join(', ')})"
      end
      self
    end

    # "intensity=max,flash=off" (DOPAIRB env var / --set option)
    def apply_string(str)
      str.to_s.split(/[,\s]+/).reject(&:empty?).each do |pair|
        k, v = pair.split("=", 2)
        raise ArgumentError, "expected key=value, got #{pair.inspect}" unless v
        set(k, v)
      end
      self
    end

    def to_h
      DESCRIPTIONS.keys.to_h { |k| [k, public_send(k)] }
    end

    def describe
      to_h.map { |k, v| format("  %-10s %-8s %s", k, show(v), DESCRIPTIONS[k]) }.join("\n")
    end

    private

    def show(v)
      case v
      when true then "on"
      when false then "off"
      else v.to_s
      end
    end

    def enum(value, list, name)
      sym = value.to_s.strip.downcase.to_sym
      return sym if list.include?(sym)
      raise ArgumentError, "#{name} must be one of #{list.join(' / ')}, got #{value.inspect}"
    end

    def bool_or_nil(value)
      case value.to_s.strip.downcase
      when "on", "true", "yes", "1" then true
      when "off", "false", "no", "0" then false
      end
    end
  end
end
