require 'helper'
require 'stringio'

require 'message'
include Flipped

shared_examples_for "Message" do
  before :each do
    @default = described_class.new
    @stream = StringIO.new
  end

  describe "self.read()" do
    it "should write/read from a stream consistently" do
      @default.write(@stream)
      @stream.rewind
      Message.read(@stream).should == @default
    end

    it "should raise an IOError on a fault" do
      lambda { Message.read(@stream) }.should raise_error IOError
    end
  end

  describe "write()" do
    it "should write a header which is the length of the following message body" do
      @default.write(@stream)

      # Should have header
      @stream.string[0..3].unpack('L')[0].should == @stream.string.length - 4
    end
  end

  describe "to_json()" do
    it "should miss out default values" do
      @default.to_json.should == "{\"json_class\":\"#{described_class}\"}"
    end

    it "should create json that can be parsed back to the original object" do
      JSON.parse(@default.to_json).should == @default
    end
  end
end

describe Message::Challenge do
  it_should_behave_like "Message"

  describe "require_password?" do
    it "should default to false" do
      @default.require_password?.should be_false
    end
  end
end

describe Message::Login do
  it_should_behave_like "Message"
end

describe Message::Accept do
  it_should_behave_like "Message"
end

describe Message::Frame do
  it_should_behave_like "Message"

  it "should serialize into and out of json with data" do
    instance = described_class.new(:frame => 'cheese')
    instance.frame.should == 'cheese'
    processed = JSON.parse(instance.to_json)
    processed.should == instance
    processed.frame.should == 'cheese'
  end  
end

describe Message::Story do
  it_should_behave_like "Message"
end