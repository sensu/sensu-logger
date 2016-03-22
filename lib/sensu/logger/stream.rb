require "sensu/json"
require "eventmachine"
require "sensu/logger/constants"

module Sensu
  module Logger
    class Stream
      # @!attribute [rw] level
      #   @return level [Symbol] current log level.
      attr_accessor :level

      # Initialize a log stream, redirect STDERR to STDOUT, create log
      # level methods, and setup the reactor log event writer.
      def initialize
        @stream = []
        @stream_callbacks = []
        @level = :info
        STDOUT.sync = true
        STDERR.reopen(STDOUT)
        self.class.create_level_methods
        setup_writer
      end

      # Create a method for each of the log levels, they call add() to
      # add log events to the log stream.
      def self.create_level_methods
        LEVELS.each do |level|
          define_method(level) do |*args|
            add(level, *args)
          end
        end
      end

      # Check to see if a log level is currently being filtered.
      #
      # @param level [Symbol] log event level.
      # @return [TrueClass, FalseClass]
      def level_filtered?(level)
        LEVELS.index(level) < LEVELS.index(@level)
      end

      # Add a log event to the log stream.
      #
      # @param level [Symbol] log event level.
      # @param args [Array] to pass to create_log_event().
      # @return [TrueClass, FalseClass] if the log event was added.
      def add(level, *args)
        unless level_filtered?(level)
          event = create_log_event(level, *args)
          if EM.reactor_running?
            schedule_write(event)
          else
            safe_write(event)
          end
          true
        else
          false
        end
      end

      # Reopen the log stream output, write log events to a file.
      #
      # @param target [IO, String] IO stream or file path.
      def reopen(target)
        @reopen = target
        case target
        when IO
          STDOUT.reopen(target)
          STDOUT.sync = true
          STDERR.reopen(STDOUT)
        when String
          if File.writable?(target) || !File.exist?(target) && File.writable?(File.dirname(target))
            STDOUT.reopen(target, "a")
            STDOUT.sync = true
            STDERR.reopen(STDOUT)
          else
            error("log file is not writable", {
              :log_file => target
            })
          end
        end
      end

      # Setup signal traps for the log stream.
      # Signals:
      #   TRAP: toggle debug logging.
      #   USR2: reopen the log file.
      def setup_signal_traps
        if Signal.list.include?("TRAP")
          Signal.trap("TRAP") do
            @level = case @level
            when :debug
              @previous_level || :info
            else
              @previous_level = @level
              :debug
            end
          end
        end
        if Signal.list.include?("USR2")
          Signal.trap("USR2") do
            if @reopen
              reopen(@reopen)
            end
          end
        end
      end

      private

      # Create a JSON log event.
      #
      # @param level [Symbol] log event level.
      # @param message [String] log event message.
      # @param data [Hash] log event data.
      # @return [String] JSON log event.
      def create_log_event(level, message, data=nil)
        event = {}
        event[:timestamp] = Time.now.strftime("%Y-%m-%dT%H:%M:%S.%6N%z")
        event[:level] = level
        event[:message] = message
        if data.is_a?(Hash)
          event.merge!(data)
        end
        Sensu::JSON.dump(event)
      end

      # Schedule a log event write, pushing the JSON log event into
      # the stream.
      #
      # @param event [String] JSON log event.
      def schedule_write(event)
        EM.schedule do
          @stream << event
          unless @stream_callbacks.empty?
            @stream_callbacks.shift.call(@stream.shift)
          end
        end
      end

      # Write a JSON log event to STDOUT, which may be redirected to a
      # log file. This method will take no action if the storage
      # device has no space remaining.
      def safe_write(event)
        begin
          puts event
        rescue Errno::ENOSPC
        end
      end

      # Register a log stream callback (a write operation).
      #
      # @param [Proc] callback to register, it will eventually be
      #   called and passed a JSON log event as a parameter.
      def register_callback(&callback)
        EM.schedule do
          if @stream.empty?
            @stream_callbacks << callback
          else
            callback.call(@stream.shift)
          end
        end
      end

      # Setup reactor log event writer. On shutdown, remaining log
      # events will be written/flushed.
      def setup_writer
        writer = Proc.new do |log_event|
          safe_write(log_event)
          EM.next_tick do
            register_callback(&writer)
          end
        end
        register_callback(&writer)
        EM.add_shutdown_hook do
          @stream.size.times do
            safe_write(@stream.shift)
          end
        end
      end
    end
  end
end
