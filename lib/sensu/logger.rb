require "sensu/logger/stream"

module Sensu
  module Logger
    class << self
      # Setup a log stream.
      #
      # @param [Hash] options to create the log stream with.
      # @option options [String] :log_level to use.
      # @option options [String] :log_file to use.
      # @return [Stream] instance of a log stream.
      def setup(options={})
        @stream = Stream.new
        if options[:log_level]
          @stream.level = options[:log_level]
        end
        if options[:log_file]
          @stream.reopen(options[:log_file])
        end
        @stream
      end

      # Retrieve the current log stream or set one up if there isn't
      # one. Note: We may need to add a mutex for thread safety.
      #
      # @param [Hash] options to pass to setup().
      # @return [Stream] instance of a log stream.
      def get(options={})
        @stream || setup(options)
      end
    end
  end
end
