# frozen_string_literal: true

module Dopairb
  # `dopa demo`: every scene once, with made-up events. Does not touch the score.
  module Demo
    E = Game::Event

    module_function

    def ev(kind, info, flags: [], gain: 120, combo: 3, streak: 0, mult: 1, level: 5)
      E.new(kind: kind, tier: nil, info: info, flags: flags, gain: gain, combo: combo, streak: streak, score: 12_480,
            mult: mult, level: level)
    end

    def cases
      [
        ["(1..100).sum", ev(:success, { type: :integer, value: 5050 })],
        ["[].first", ev(:success, { type: :nil })],
        ["1 < 2", ev(:success, { type: :true })],
        ["[] .any?", ev(:success, { type: :false })],
        ["2**64", ev(:success, { type: :integer, value: 2**64 })],
        ["'dopamine ' * 12", ev(:success, { type: :string, length: 108, head: "dopamine " * 12 })],
        ["(1..24).to_a", ev(:success, { type: :array, size: 24 })],
        ["def boost = :on", ev(:definition, { type: :definition, what: :method, name: "boost" })],
        ["3.times { puts }", ev(:success, { type: :nil, out_lines: 120 }, flags: [:output_rain])],
        ["x = 1", ev(:success, { type: :integer, value: 1 }, flags: [:first_hit], combo: 1)],
        ["10.times.sum", ev(:success, { type: :integer, value: 45 }, flags: [:combo_milestone, :combo_mega], combo: 10, gain: 1350)],
        ["1 + ", ev(:failure, { type: :syntax, class_name: "SyntaxError", line: 1, column: 4, detail: "unexpected end-of-input; expected an expression after the operator" })],
        ["undefined_thing", ev(:failure, { type: :name, class_name: "NameError", name: "undefined_thing", message: "undefined local variable or method 'undefined_thing' for main" }, combo: 0, streak: 1)],
        ["1.shout", ev(:failure, { type: :nomethod, class_name: "NoMethodError", name: "shout", receiver: "Integer", message: "undefined method 'shout' for an instance of Integer" }, combo: 0, streak: 2)],
        ["1 + '1'", ev(:failure, { type: :type, class_name: "TypeError", sides: %w[String Integer], message: "String can't be coerced into Integer" }, combo: 0, streak: 3)],
        ["[1].first(1, 2)", ev(:failure, { type: :argument, class_name: "ArgumentError", sides: ["given 2", "expected 0..1"], message: "wrong number of arguments (given 2, expected 0..1)" }, combo: 0, streak: 4)],
        ["raise 'boom'", ev(:failure, { type: :other, class_name: "RuntimeError", message: "boom" }, combo: 0, streak: 5)],
        ["1 + 1", ev(:success, { type: :integer, value: 2 }, flags: [:comeback], combo: 1, streak: 5, gain: 600)],
        ["loop {}", ev(:interrupt, { charge: 60 })],
        ["2**128", ev(:success, { type: :integer, value: 2**128 }, flags: [:new_record, :record_jump], gain: 420)],
        ["[3, 1, 2].sort", ev(:success, { type: :array, size: 3 }, flags: [:critical], gain: 960, mult: 8)],
        ["12.fdiv(5)", ev(:success, { type: :float, value: 2.4 }, flags: [:fever], combo: 12, gain: 1100, mult: 2)],
        ["21.0 * 2", ev(:success, { type: :float, value: 42.0 }, flags: [:fever, :combo_best], combo: 13, gain: 1200, mult: 2)],
        ["rand(777)", ev(:success, { type: :integer, value: 777 }, flags: [:jackpot], gain: 6_400, mult: 16)],
        ["'level' * 2", ev(:success, { type: :string, length: 10, head: "levellevel", art: :great_wave, art_new: true, gallery: [1, 5] },
                           flags: [:level_up], gain: 200, level: 6)],
      ]
    end

    # Let the sound ring out so the next one does not step on it.
    def wait_for_sound(config, scene, t0)
      return unless config.sound == :sfx && scene&.sfx && Sound.available?
      ends = (scene.pre + scene.impact_at) * config.duration + Sound.tail(scene.sfx)
      wait = ends - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait
      sleep 0.02 while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline && !Term.input_pending?
    end

    def run(mod)
      d = mod.session&.director || Director.new(mod.config)
      unless mod.active?
        puts "dopairb: not active (no terminal or intensity=off)"
        return
      end
      prompt = "\e[1;35mdopa\e[0m> "
      cases.each do |code, event|
        break if Term.input_pending?
        line = "#{prompt}#{IRB::Color.colorize_code(code, complete: true)}"
        Term.write("#{line}\r\n")
        shot = InputShot.new(rows: [line], lines: [[6, code]], code: code, screen_width: Term.cols)
        if event.kind == :failure && event.info[:type] == :syntax
          event.info[:column] = [code.size, event.info[:column]].min
        end
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        scene = d.play_event(event, input: shot, pre: event.kind == :success ? mod.config.charge : 0)
        Term.write("\e[2m=> (demo)\e[0m\r\n")
        wait_for_sound(mod.config, scene, t0)
        sleep 0.4
      end
      Term.write("\e[0m")
    end
  end
end
