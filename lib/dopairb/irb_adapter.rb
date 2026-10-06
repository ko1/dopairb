# frozen_string_literal: true

module Dopairb
  # Every dependency on IRB internals lives in this file.
  #
  # Tested with IRB 1.14 - 1.18. Public: IRB::Command.register, IRB.conf[:AT_EXIT].
  # Internal (prepended): IRB::Context#evaluate, which runs one statement and
  # raises what it raises; IRB prints `=> value` or the error afterwards.
  module IrbAdapter
    SUPPORTED = Gem::Requirement.new(">= 1.14.0", "< 2")

    class << self
      def supported?
        defined?(IRB::VERSION) && SUPPORTED.satisfied_by?(Gem::Version.new(IRB::VERSION))
      end

      def install
        return false unless supported?
        return true if @installed
        IRB::Context.prepend(ContextHook)
        IRB::WorkSpace.prepend(WorkSpaceHook)
        IRB::Command.register(:dopa, DopaCommand) if defined?(IRB::Command) && IRB::Command.respond_to?(:register)
        IRB.conf[:AT_EXIT] ||= []
        IRB.conf[:AT_EXIT] << proc do
          nested = defined?(IRB::Irb.run_nesting_depth) && IRB::Irb.run_nesting_depth > 0
          Dopairb.session&.finish unless nested
        end
        @installed = true
      end

      # Is the current session one that binding.irb opened?
      def from_binding?
        ctx = IRB.conf[:MAIN_CONTEXT]
        ctx.respond_to?(:from_binding?) && ctx.from_binding? ? true : false
      rescue StandardError
        false
      end

      def expression?(statement)
        defined?(IRB::Statement::Expression) && IRB::Statement::Expression === statement
      end
    end

    module ContextHook
      def evaluate(statement, line_no)
        session = Dopairb.session
        return super unless session&.active? && IrbAdapter.expression?(statement)
        session.around_eval(statement.code, -> { last_value }) { super }
      end
    end

    # Keep our own frames out of user-visible backtraces, like IRB does for itself.
    module WorkSpaceHook
      OWN = %r{/lib/dopairb(?:/[\w/]+)?\.rb:}

      def filter_backtrace(bt)
        return nil if bt =~ OWN
        super
      end
    end

    if defined?(IRB::Command::Base)
      class DopaCommand < IRB::Command::Base
        category "dopairb"
        description "Tune dopairb effects. `dopa help` for details."

        def execute(arg)
          Dopairb.command(arg.to_s)
        end
      end
    end
  end
end
