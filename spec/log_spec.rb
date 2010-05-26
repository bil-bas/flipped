require 'helper'

require 'stringio'

LOG_FILE = StringIO.new

require 'log'
include Flipped

class LogTest
  include Log
end

describe Log do
  describe "self.log()" do
    it "should return a logger object" do
      LogTest.log.should be_a_kind_of Logger
    end

    it "should return a logger with the correct progname" do
      LogTest.log.progname.should == LogTest.name
    end
  end

  describe "log()" do
    it "should return a logger object" do
      LogTest.new.log.should be_a_kind_of Logger
    end

    it "should return a logger with the correct progname" do
      LogTest.new.log.progname.should == LogTest.name
    end
  end
end