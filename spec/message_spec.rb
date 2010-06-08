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
    it "should write the message onto the stream as json" do
      @default.write(@stream)

      # Should have header
      @stream.string.should == "#{@default.to_json}\n"
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

  describe "name()" do
    it "should be preserved" do
      stream = StringIO.new
      message = described_class.new(:name => "My name")
      message.write(stream)
      stream.rewind
      message2 = Message.read(stream)
      message2.name.should == "My name"
    end
  end
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

describe Message::SiDStarted do
  it_should_behave_like "Message"
end

describe Message::StoryNamed do
  it_should_behave_like "Message"
end

describe Message::StoryStarted do
  it_should_behave_like "Message"

  it "should deserialize time correctly" do
    time = Time.now
    instance = described_class.new(:started_at => time)
    processed = JSON.parse(instance.to_json)
    # Allow for milliseconds, which we don't care about, being wiped in transit.
    (time - processed.started_at).abs.should < 1
  end
end

describe Message::Connected do
  it_should_behave_like "Message"

  it "should store and retrieve data" do
    message = described_class.new(:id => 12, :name => 'fred', :role => :player)
    message = JSON.parse(message.to_json)
    message.id.should == 12
    message.name.should == 'fred'
    message.role.should == :player
  end
end

describe Message::Disconnected do
  it_should_behave_like "Message"
end

describe Message::Rename do
  it_should_behave_like "Message"
end

describe Message::Chat do
  it_should_behave_like "Message"
end

describe Message::Kick do
 it_should_behave_like "Message"
end

describe Message::Quit do
 it_should_behave_like "Message"
end