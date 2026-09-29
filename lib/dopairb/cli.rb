# frozen_string_literal: true

require "optparse"
require_relative "../dopairb"

module Dopairb
  # `dopairb [dopairb options] [--] [irb options]`
  module CLI
    module_function

    def parser(settings)
      OptionParser.new do |o|
        o.require_exact = true
        o.banner = "Usage: dopairb [options] [-- irb options]"
        o.separator ""
        o.separator "IRB with fireworks. Every other option is handed to IRB."
        o.separator ""
        o.on("--intensity=LEVEL", Config::INTENSITIES.map(&:to_s), "off / low / normal (default) / max") { |v| settings << [:intensity, v] }
        o.on("--calm", "low intensity, no flash, shorter effects") { settings.concat([[:intensity, :low], [:flash, :off], [:duration, 0.7]]) }
        o.on("--max", "everything at maximum") { settings << [:intensity, :max] }
        o.on("--party", "max + full-screen flash + bell") { settings.concat([[:intensity, :max], [:flash, :full], [:sound, true]]) }
        o.on("--[no-]flash[=MODE]", "flash: off / soft (default) / full") { |v| settings << [:flash, v.nil? ? :soft : (v == false ? :off : v)] }
        o.on("--[no-]motion", "animations (default on)") { |v| settings << [:motion, v] }
        o.on("--[no-]sound", "terminal bell on big moments (default off)") { |v| settings << [:sound, v] }
        o.on("--[no-]hud", "COMBO / SCORE next to the prompt (default on)") { |v| settings << [:hud, v] }
        o.on("--[no-]keys", "per-keystroke effects (default on)") { |v| settings << [:keys, v] }
        o.on("--[no-]intro", "title animation (default on)") { |v| settings << [:intro, v] }
        o.on("--duration=X", Float, "effect length multiplier") { |v| settings << [:duration, v] }
        o.on("--set=K=V,...", "any setting, same format as $DOPAIRB") { |v| settings << [:string, v] }
        o.on("--version", "print version") do
          puts "dopairb #{VERSION} (irb #{IRB::VERSION}, reline #{Reline::VERSION})"
          exit
        end
        o.on("-h", "--help", "this help") do
          puts o
          puts
          puts "Settings (also via DOPAIRB=\"key=value,...\" or `dopa key=value` inside the session):"
          puts Config.new.describe
          exit
        end
      end
    end

    def split_args(argv)
      return [argv[0...argv.index("--")], argv[(argv.index("--") + 1)..]] if argv.include?("--")
      argv.partition { |a| ours?(a) }
    end

    def ours?(arg)
      return true if %w[-h --help --version].include?(arg)
      return false unless arg.start_with?("--")
      parser([]).parse([arg])
      true
    rescue OptionParser::InvalidOption, OptionParser::AmbiguousOption
      false
    rescue OptionParser::ParseError
      true
    end

    def start(argv = ARGV)
      ours, irb_args = split_args(argv.dup)
      settings = []
      parser(settings).parse!(ours)
      settings.each do |k, v|
        k == :string ? Dopairb.config.apply_string(v) : Dopairb.config.set(k, v)
      end
      run_irb(irb_args)
    rescue OptionParser::ParseError, ArgumentError => e
      warn "dopairb: #{e.message}"
      exit 2
    end

    def run_irb(irb_args)
      STDOUT.sync = true
      $0 = "dopairb"
      IRB.setup(nil, argv: irb_args)
      Dopairb.enable
      IRB.conf[:PROMPT][:DOPAIRB] = {
        PROMPT_I: "dopairb(%m):%03n> ",
        PROMPT_S: "dopairb(%m):%03n%l ",
        PROMPT_C: "dopairb(%m):%03n* ",
        RETURN: "=> %s\n",
      }
      IRB.conf[:PROMPT_MODE] = :DOPAIRB if IRB.conf[:PROMPT_MODE] == :DEFAULT
      irb = IRB::Irb.new
      Dopairb.session.intro
      irb.run(IRB.conf)
    end
  end
end
