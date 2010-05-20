require "helper"

require 'sid'
include Flipped

describe SiD do
  before :each do
    @sid = SiD.new(File.join('..', 'test_data', 'sid'))
  end

  it "read in the correct values" do
    @sid.auto_host?.should be_true
    @sid.auto_join?.should be_false
    @sid.fullscreen?.should be_false
    @sid.flip_book?.should be_true
    @sid.hard_to_quit_mode?.should be_false
    @sid.port.should == 7778
    @sid.screen_width.should == 1280
    @sid.screen_height.should == 960
    @sid.time_limit.should == 60
  end
end