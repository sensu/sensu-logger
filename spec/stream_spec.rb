require File.join(File.dirname(__FILE__), "helpers")
require "sensu/logger/stream"
require "tempfile"

describe "Sensu::Logger::Stream" do
  include Helpers

  before do
    @stream = Sensu::Logger::Stream.new
  end

  it "can log events with different levels" do
    @stream.debug("some debug info", {:foo => "bar"}).should be_false
    @stream.info("some info", {:foo => "bar"}).should be_true
    @stream.warn("a warning", {:foo => "bar"}).should be_true
    @stream.error("an error", {:foo => "bar"}).should be_true
    @stream.fatal("something exploded", {:foo => "bar"}).should be_true
    @stream.level = :debug
    @stream.debug("some debug info", {:foo => "bar"}).should be_true
    @stream.info("some info", {:foo => "bar"}).should be_true
    @stream.level = :warn
    @stream.info("some info", {:foo => "bar"}).should be_false
    @stream.warn("a warning", {:foo => "bar"}).should be_true
  end

  it "can reopen STDERR/STDOUT and redirect them to a log file" do
    stdout = STDOUT.dup
    file = Tempfile.new("sensu-logger")
    @stream.reopen(file.path)
    @stream.info("some info", {:foo => "bar"}).should be_true
    @stream.reopen(stdout)
    file_contents = IO.read(file.path)
    file_contents.should match(/timestamp/)
    file_contents.should match(/"message":"some info"/)
    file_contents.should match(/"foo":"bar"/)
    @stream.reopen("/untouchable.log")
    @stream.info("some info", {:foo => "bar"}).should be_true
  end

  it "can setup signal traps to toggle debug logging and reopen the log file" do
    @stream.setup_signal_traps
    @stream.debug("some debug info", {:foo => "bar"}).should be_false
    @stream.info("some info", {:foo => "bar"}).should be_true
    Process.kill("TRAP", Process.pid)
    sleep 0.5
    @stream.debug("some debug info", {:foo => "bar"}).should be_true
    @stream.info("some info", {:foo => "bar"}).should be_true
    Process.kill("TRAP", Process.pid)
    sleep 0.5
    @stream.debug("some debug info", {:foo => "bar"}).should be_false
    @stream.info("some info", {:foo => "bar"}).should be_true
    @stream.level = :warn
    @stream.info("some info", {:foo => "bar"}).should be_false
    Process.kill("TRAP", Process.pid)
    sleep 0.5
    @stream.debug("some debug info", {:foo => "bar"}).should be_true
    @stream.info("some info", {:foo => "bar"}).should be_true
    Process.kill("TRAP", Process.pid)
    sleep 0.5
    @stream.debug("some debug info", {:foo => "bar"}).should be_false
    @stream.info("some info", {:foo => "bar"}).should be_false
    @stream.warn("a warning", {:foo => "bar"}).should be_true
    @stream.reopen(STDOUT)
    Process.kill("USR2", Process.pid)
    sleep 0.5
    @stream.error("an error", {:foo => "bar"}).should be_true
  end

  it "can operate as expected within the eventmachine reactor" do
    async_wrapper do
      stdout = STDOUT.dup
      file = Tempfile.new("sensu-logger")
      @stream.reopen(file.path)
      @stream.debug("some debug info", {:foo => "bar"}).should be_false
      @stream.info("some info", {:foo => "bar"}).should be_true
      @stream.warn("a warning", {:foo => "bar"}).should be_true
      @stream.error("an error", {:foo => "bar"}).should be_true
      timer(1) do
        @stream.reopen(stdout)
        expected = [
          {:level => "info", :message => "some info", :foo => "bar"},
          {:level => "warn", :message => "a warning", :foo => "bar"},
          {:level => "error", :message => "an error", :foo => "bar"}
        ]
        file_contents = IO.read(file.path)
        parsed_contents = file_contents.lines.map do |line|
          parsed_line = MultiJson.load(line, :symbolize_keys => true)
          parsed_line.delete(:timestamp)
          parsed_line
        end
        parsed_contents.should eq(expected)
        async_done
      end
    end
  end

  it "can write remaining log events to a log file when the eventmachine reactor stops" do
    stdout = STDOUT.dup
    file = Tempfile.new("sensu-logger")
    async_wrapper do
      @stream.reopen(file.path)
      1000.times do
        @stream.info("some info", {:foo => "bar"}).should be_true
      end
      EM.stop
    end
    @stream.reopen(stdout)
    IO.read(file.path).split("\n").size.should eq(1000)
  end
end
