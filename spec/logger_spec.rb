require File.join(File.dirname(__FILE__), "helpers")
require "sensu/logger"

describe "Sensu::Logger" do
  include Helpers

  it "can provide the logger API" do
    Sensu::Logger.should respond_to(:setup, :get)
  end

  it "can set up a log stream" do
    logger = Sensu::Logger.setup
    logger.info("some info", {:foo => "bar"}).should be_true
    logger.level = :warn
    logger.info("some info", {:foo => "bar"}).should be_false
  end

  it "can retrive the current log stream" do
    logger = Sensu::Logger.setup
    Sensu::Logger.get.should eq(logger)
    Sensu::Logger.get.should eq(logger)
  end

  it "can setup a log stream if one doesn't exist" do
    logger = Sensu::Logger.get
    logger.info("some info", {:foo => "bar"}).should be_true
  end

  it "can setup a log stream with a log level and file" do
    stdout = STDOUT.dup
    file = Tempfile.new("sensu-logger")
    logger = Sensu::Logger.setup(:log_level => :warn, :log_file => file.path)
    logger.info("some info", {:foo => "bar"}).should be_false
    logger.warn("a warning", {:foo => "bar"}).should be_true
    file_contents = IO.read(file.path)
    file_contents.should match(/a warning/)
    logger.reopen(stdout)
    logger.warn("a warning", {:foo => "bar"}).should be_true
  end

  it "can setup a log stream with options if one doesn't exist" do
    logger = Sensu::Logger.get(:log_level => :warn)
    logger.info("some info", {:foo => "bar"}).should be_false
    logger.warn("a warning", {:foo => "bar"}).should be_true
  end
end
