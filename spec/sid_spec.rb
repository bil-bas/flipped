require "helper"

require 'sid'
include Flipped

OUTPUT_DIR = File.join('..', 'test_data', 'output')

describe SiD do
  before :each do
    @sid = SiD.new(File.join('..', 'test_data', 'sid'))
  end

  it "read in the correct values" do
    @sid.auto_host?.should be_true
    @sid.auto_join?.should be_false
    @sid.default_server_address.should == '127.0.0.1'
    @sid.fullscreen?.should be_false
    @sid.flip_book?.should be_true
    @sid.hard_to_quit_mode?.should be_false
    @sid.port.should == 7778
    @sid.screen_width.should == 1280
    @sid.screen_height.should == 960
    @sid.time_limit.should == 60
  end

  describe "write_settings()" do
    it "should write out the same values that it read in" do
      FileUtils.rm_rf OUTPUT_DIR if File.exists? OUTPUT_DIR
      FileUtils.mkdir_p File.join(OUTPUT_DIR, 'settings')
      @sid.instance_variable_set('@root', OUTPUT_DIR)
      @sid.write_settings
      {
              'autoHost.ini' => '1',
              'autoJoin.ini' => '0',
              'defaultServerAddress.ini' => '127.0.0.1',
              'flipBook.ini' => '1',
              'fullscreen.ini' => '0',              
              'hardToQuitMode.ini' => '0',
              'port.ini' => '7778',
              'screenHeight.ini' => '960',
              'screenWidth.ini' => '1280',              
              'timeLimit.ini' => '60',
      }.each_pair do |filename, value|
         File.read(File.join(OUTPUT_DIR, 'settings', filename)).strip.should == value
      end
    end
  end
end