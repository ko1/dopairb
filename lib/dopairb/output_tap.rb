# frozen_string_literal: true

module Dopairb
  # Watches writes to STDOUT/STDERR. Before any program output reaches the
  # terminal, transient decorations get out of the way; during an eval it
  # also counts output lines for OUTPUT RAIN.
  module OutputTap
    @counting = false
    @lines = 0
    @bytes = 0

    class << self
      attr_reader :lines, :bytes

      def install
        return if @installed
        [STDOUT, STDERR].each { |io| io.singleton_class.prepend(Hook) }
        Kernel.prepend(PrivateSpawnHook)
        [Kernel.singleton_class, Process.singleton_class].each { |m| m.prepend(SpawnHook) }
        IO.singleton_class.prepend(PopenHook)
        @installed = true
      end

      def start
        @lines = 0
        @bytes = 0
        @spawned = false
        @counting = true
      end

      def stop
        @counting = false
        [@lines, @bytes]
      end

      def output? = @bytes > 0 || @spawned

      def before_write(str)
        Term::LOCK.synchronize { Term.yield_to_output } if Term.overlay
        return unless @counting
        s = str.to_s
        @bytes += s.bytesize
        @lines += s.count("\n")
      rescue StandardError
        nil
      end

      # Our own helper processes (sound players) do not count as output.
      def quietly
        prev = Thread.current[:dopairb_quiet]
        Thread.current[:dopairb_quiet] = true
        yield
      ensure
        Thread.current[:dopairb_quiet] = prev
      end

      # A child process may write straight to the tty: stop decorating.
      def spawned!
        return if Thread.current[:dopairb_quiet]
        @spawned = true if @counting
        Term::LOCK.synchronize { Term.yield_to_output } if Term.overlay
      end
    end

    module Hook
      def write(*args)
        args.each { |a| OutputTap.before_write(a) }
        super
      end

      def syswrite(str)
        OutputTap.before_write(str)
        super
      end

      def write_nonblock(str, *rest, **kw)
        OutputTap.before_write(str)
        super
      end
    end

    module SpawnHook
      %i[system spawn].each do |m|
        define_method(m) do |*args, **kw, &blk|
          OutputTap.spawned!
          super(*args, **kw, &blk)
        end
      end
    end

    # Kernel#system and friends are private; keep them that way.
    module PrivateSpawnHook
      include SpawnHook
      private(*SpawnHook.instance_methods(false))
    end

    module PopenHook
      def popen(*args, **kw, &blk)
        OutputTap.spawned!
        super
      end
    end
  end
end
