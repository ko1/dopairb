# frozen_string_literal: true

module Dopairb
  # Cheap, side-effect free facts about results and exceptions. Never calls
  # the user's #inspect / #to_s: those may be slow, raise, or print.
  module Probe
    KERNEL_CLASS = Kernel.instance_method(:class)
    MODULE_NAME = Module.instance_method(:name)
    STR_LENGTH = String.instance_method(:length)
    STR_SLICE = String.instance_method(:[])
    ARY_SIZE = Array.instance_method(:size)
    HASH_SIZE = Hash.instance_method(:size)
    SYM_NAME = Symbol.instance_method(:name)
    INT_BITS = Integer.instance_method(:bit_length)
    INT_TO_S = Integer.instance_method(:to_s)
    EXC_MESSAGE = Exception.instance_method(:message)

    HUGE_BITS = 4000

    module_function

    def value(v, code = "")
      info = classify(v)
      if (m = code.match(/\A\s*def\s+(?:self\.)?([^\s(=;]+)/)) && info[:type] == :symbol
        return { type: :definition, what: :method, name: m[1] }
      end
      if (m = code.match(/\A\s*(class|module)\s+(?!<<)([A-Z][\w:]*)/))
        return { type: :definition, what: m[1].to_sym, name: m[2] }
      end
      info
    rescue StandardError
      { type: :object, class_name: "?" }
    end

    def classify(v)
      if NilClass === v then { type: :nil }
      elsif TrueClass === v then { type: :true }
      elsif FalseClass === v then { type: :false }
      elsif Integer === v
        bits = INT_BITS.bind_call(v)
        if bits > HUGE_BITS
          { type: :huge, digits: (bits * 0.30103).floor + 1 }
        else
          { type: :integer, value: v }
        end
      elsif Float === v then { type: :float, value: v }
      elsif String === v
        len = STR_LENGTH.bind_call(v)
        { type: :string, length: len, head: sanitize(STR_SLICE.bind_call(v, 0, 160) || "") }
      elsif Array === v then { type: :array, size: ARY_SIZE.bind_call(v) }
      elsif Hash === v then { type: :hash, size: HASH_SIZE.bind_call(v) }
      elsif Symbol === v then { type: :symbol, name: SYM_NAME.bind_call(v) }
      else { type: :object, class_name: class_name(v) }
      end
    end

    def class_name(v)
      MODULE_NAME.bind_call(KERNEL_CLASS.bind_call(v)) || "(anonymous)"
    rescue TypeError
      "BasicObject"
    end

    def sanitize(s)
      s = s.dup.force_encoding(Encoding::UTF_8)
      s = s.scrub("?")
      s.gsub(/[\p{Cc}\p{Cf}]/) { |c| c == "\n" ? " " : "." }
    rescue StandardError
      "?"
    end

    def message(exc)
      sanitize(EXC_MESSAGE.bind_call(exc).to_s.lines.first.to_s.chomp)
    rescue Exception # rubocop:disable Lint/RescueException
      ""
    end

    def exception(exc, code = "")
      klass = MODULE_NAME.bind_call(KERNEL_CLASS.bind_call(exc)) || "Exception"
      msg = message(exc)
      info = { class_name: klass, message: msg }
      case exc
      when SyntaxError
        info[:type] = :syntax
        info.merge!(syntax_location(code))
      when NoMethodError
        info[:type] = :nomethod
        info[:name] = safe_name(exc)
        info[:receiver] = receiver_name(exc, msg)
      when NameError
        info[:type] = :name
        info[:name] = safe_name(exc)
      when TypeError
        info[:type] = :type
        info[:sides] = type_sides(msg)
      when ArgumentError
        info[:type] = :argument
        info[:sides] = argument_sides(msg)
      else
        info[:type] = interrupt?(exc) ? :interrupt : :other
      end
      info
    rescue StandardError
      { type: :other, class_name: "Exception", message: "" }
    end

    def interrupt?(exc)
      Interrupt === exc || (defined?(IRB::Abort) && IRB::Abort === exc)
    end

    def safe_name(exc)
      n = NameError.instance_method(:name).bind_call(exc)
      Symbol === n ? SYM_NAME.bind_call(n) : nil
    rescue StandardError
      nil
    end

    def receiver_name(exc, msg)
      if (m = msg.match(/for (?:an instance of |)([A-Z][\w:]*|nil|true|false)/))
        return m[1]
      end
      r = NameError.instance_method(:receiver).bind_call(exc)
      Module === r ? MODULE_NAME.bind_call(r).to_s : class_name(r)
    rescue StandardError
      "?"
    end

    def syntax_location(code)
      return {} unless defined?(Prism)
      err = Prism.parse(code).errors.first
      return {} unless err
      loc = err.location
      { line: loc.start_line, column: loc.start_column, detail: sanitize(err.message) }
    rescue StandardError
      {}
    end

    def type_sides(msg)
      if (m = msg.match(/(?:no implicit conversion of|conversion of) (\S+) into (\S+)/))
        [m[1], m[2]]
      elsif (m = msg.match(/(\S+) can't be coerced into (\S+)/))
        [m[1], m[2]]
      elsif (m = msg.match(/wrong argument type (\S+) \(expected (\S+)\)/))
        [m[1], m[2]]
      else
        %w[TYPE TYPE]
      end
    end

    def argument_sides(msg)
      if (m = msg.match(/given (\d+), expected ([\d.+\-]+)/))
        ["given #{m[1]}", "expected #{m[2]}"]
      elsif (m = msg.match(/(missing|unknown) keywords?: (.+)/))
        [m[1], m[2][0, 20]]
      else
        %w[ARG ARG]
      end
    end
  end
end
