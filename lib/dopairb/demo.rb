# frozen_string_literal: true

module Dopairb
  # `dopa demo`: every scene once, with made-up events. Does not touch the score.
  module Demo
    E = Game::Event

    module_function

    def ev(kind, info, flags: [], gain: 120, combo: 3, streak: 0)
      E.new(kind: kind, tier: nil, info: info, flags: flags, gain: gain, combo: combo, streak: streak, score: 12_480)
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
      ]
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
        d.play_event(event, input: shot, pre: event.kind == :success ? mod.config.charge : 0)
        Term.write("\e[2m=> (demo)\e[0m\r\n")
        sleep 0.15
      end
      Term.write("\e[0m")
    end
  end
end
