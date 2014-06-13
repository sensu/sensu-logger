require File.join(File.dirname(__FILE__), "helpers")
require "sensu/logger"

describe "Sensu::Logger" do
  include Helpers

  it "can provide the logger API" do
    expect(Sensu::Logger).to respond_to(:setup, :get)
  end

  it "can set up a log stream" do
    logger = Sensu::Logger.setup
    expect(logger.info("some info", {:foo => "bar"})).to be(true)
    logger.level = :warn
    expect(logger.info("some info", {:foo => "bar"})).to be(false)
  end

  it "can retrive the current log stream" do
    logger = Sensu::Logger.setup
    expect(Sensu::Logger.get).to eq(logger)
    expect(Sensu::Logger.get).to eq(logger)
  end

  it "can setup a log stream if one doesn't exist" do
    logger = Sensu::Logger.get
    expect(logger.info("some info", {:foo => "bar"})).to be(true)
  end

  it "can setup a log stream with a log level and file" do
    stdout = STDOUT.dup
    file = Tempfile.new("sensu-logger")
    logger = Sensu::Logger.setup(:log_level => :warn, :log_file => file.path)
    expect(logger.info("some info", {:foo => "bar"})).to be(false)
    expect(logger.warn("a warning", {:foo => "bar"})).to be(true)
    file_contents = IO.read(file.path)
    expect(file_contents).to match(/a warning/)
    logger.reopen(stdout)
    expect(logger.warn("a warning", {:foo => "bar"})).to be(true)
  end

  it "can setup a log stream with options if one doesn't exist" do
    logger = Sensu::Logger.get(:log_level => :warn)
    expect(logger.info("some info", {:foo => "bar"})).to be(false)
    expect(logger.warn("a warning", {:foo => "bar"})).to be(true)
  end
end
