require File.join(File.dirname(__FILE__), "helpers")
require "sensu/logger/stream"
require "tempfile"

describe "Sensu::Logger::Stream" do
  include Helpers

  before do
    @stream = Sensu::Logger::Stream.new
  end

  it "can log events with different levels" do
    expect(@stream.debug("some debug info", {:foo => "bar"})).to be(false)
    expect(@stream.info("some info", {:foo => "bar"})).to be(true)
    expect(@stream.warn("a warning", {:foo => "bar"})).to be(true)
    expect(@stream.error("an error", {:foo => "bar"})).to be(true)
    expect(@stream.fatal("something exploded", {:foo => "bar"})).to be(true)
    @stream.level = :debug
    expect(@stream.debug("some debug info", {:foo => "bar"})).to be(true)
    expect(@stream.info("some info", {:foo => "bar"})).to be(true)
    @stream.level = :warn
    expect(@stream.info("some info", {:foo => "bar"})).to be(false)
    expect(@stream.warn("a warning", {:foo => "bar"})).to be(true)
  end

  it "can reopen STDERR/STDOUT and redirect them to a log file" do
    stdout = STDOUT.dup
    file = Tempfile.new("sensu-logger")
    @stream.reopen(file.path)
    expect(@stream.info("some info", {:foo => "bar"})).to be(true)
    @stream.reopen(stdout)
    file_contents = IO.read(file.path)
    expect(file_contents).to match(/timestamp/)
    expect(file_contents).to match(/"message":"some info"/)
    expect(file_contents).to match(/"foo":"bar"/)
    @stream.reopen("/untouchable.log")
    expect(@stream.info("some info", {:foo => "bar"})).to be(true)
  end

  it "can setup signal traps to toggle debug logging and reopen the log file" do
    @stream.setup_signal_traps
    expect(@stream.debug("some debug info", {:foo => "bar"})).to be(false)
    expect(@stream.info("some info", {:foo => "bar"})).to be(true)
    Process.kill("TRAP", Process.pid)
    sleep 0.5
    expect(@stream.debug("some debug info", {:foo => "bar"})).to be(true)
    expect(@stream.info("some info", {:foo => "bar"})).to be(true)
    Process.kill("TRAP", Process.pid)
    sleep 0.5
    expect(@stream.debug("some debug info", {:foo => "bar"})).to be(false)
    expect(@stream.info("some info", {:foo => "bar"})).to be(true)
    @stream.level = :warn
    expect(@stream.info("some info", {:foo => "bar"})).to be(false)
    Process.kill("TRAP", Process.pid)
    sleep 0.5
    expect(@stream.debug("some debug info", {:foo => "bar"})).to be(true)
    expect(@stream.info("some info", {:foo => "bar"})).to be(true)
    Process.kill("TRAP", Process.pid)
    sleep 0.5
    expect(@stream.debug("some debug info", {:foo => "bar"})).to be(false)
    expect(@stream.info("some info", {:foo => "bar"})).to be(false)
    expect(@stream.warn("a warning", {:foo => "bar"})).to be(true)
    @stream.reopen(STDOUT)
    Process.kill("USR2", Process.pid)
    sleep 0.5
    expect(@stream.error("an error", {:foo => "bar"})).to be(true)
  end

  it "can operate as expected within the eventmachine reactor" do
    async_wrapper do
      stdout = STDOUT.dup
      file = Tempfile.new("sensu-logger")
      @stream.reopen(file.path)
      expect(@stream.debug("some debug info", {:foo => "bar"})).to be(false)
      expect(@stream.info("some info", {:foo => "bar"})).to be(true)
      expect(@stream.warn("a warning", {:foo => "bar"})).to be(true)
      expect(@stream.error("an error", {:foo => "bar"})).to be(true)
      timer(1) do
        @stream.reopen(stdout)
        expected = [
          {:level => "info", :message => "some info", :foo => "bar"},
          {:level => "warn", :message => "a warning", :foo => "bar"},
          {:level => "error", :message => "an error", :foo => "bar"}
        ]
        file_contents = IO.read(file.path)
        parsed_contents = file_contents.lines.map do |line|
          parsed_line = Sensu::JSON.load(line)
          parsed_line.delete(:timestamp)
          parsed_line
        end
        expect(parsed_contents).to eq(expected)
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
        expect(@stream.info("some info", {:foo => "bar"})).to be(true)
      end
      EM.stop
    end
    @stream.reopen(stdout)
    expect(IO.read(file.path).split("\n").size).to eq(1000)
  end
end
