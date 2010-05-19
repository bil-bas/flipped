require "spec"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'flipped'))

require 'packet'
include Flipped

shared_examples_for "Packet" do
  before :each do
    @default = described_class.new
  end
  
  it "should serialize into and out of json" do
    JSON.parse(@default.to_json).should == @default
  end

  describe "to_json()" do
    it "should miss out default values" do
      @default.to_json.should == "{\"json_class\":\"#{described_class}\"}"
    end
  end
end

describe Challenge do
  it_should_behave_like "Packet"

  describe "require_password?" do
    it "should default to false" do
      @default.require_password?.should be_false
    end
  end
end

describe Login do
  it_should_behave_like "Packet"
end

describe Accept do
  it_should_behave_like "Packet"
end

describe Frame do
  it_should_behave_like "Packet"

  it "should serialize into and out of json with data" do
    instance = described_class.new(:frame => 'cheese')
    instance.frame.should == 'cheese'
    processed = JSON.parse(instance.to_json)
    processed.should == instance
    processed.frame.should == 'cheese'
  end  
end

describe Clear do
  it_should_behave_like "Packet"
end