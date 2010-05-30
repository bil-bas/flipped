require "helper"

require 'sid'
include Flipped

OUTPUT_DIR = File.join(ROOT, 'test_data', 'output')
SID_DIR = 'C:\Users\Spooner\Desktop\SiD PLAY 15'

describe SiD do
  before :each do
    @sid = SiD.new(File.join(ROOT, 'test_data', 'sid'))
    @sid_with_flip_books = SiD.new(File.join(ROOT, 'test_data', 'sid_with_flip_books'))
    @sid_flip_books_dir = File.join(ROOT, 'test_data', 'sid_with_flip_books', 'flipBooks')
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

  describe "run()" do
    it "should run the game" do
      @sid.instance_variable_set('@root', SID_DIR)
      @sid.run
    end
  end

  describe "valid_root?()" do
    it "should recognise a real installation of SiD" do
      @sid.valid_root?(SID_DIR).should be_true
    end

    it "should reject a non-installation of SiD" do
      @sid.valid_root?(File.dirname(__FILE__)).should be_false      
    end
  end

  describe "flip_book_directory()" do
    it "should give the path to the indexed flip-book (even if it doesn't exist" do
      (1..4).each do |i|
        @sid_with_flip_books.flip_book_directory(i).should == "#{@sid_flip_books_dir}/0000#{i}"
      end
    end
  end

  describe "flip_book()" do
    it "should create the automatic flip-book at the appropriate index" do
      (1..3).each do |i|
        @sid_with_flip_books.flip_book(i).should == Book.new("#{@sid_flip_books_dir}/0000#{i}")
      end
    end
  end

  describe "number_of_automatic_flip_books()" do
    it "should find the number of flip-books in the flipBooks directory" do
      @sid_with_flip_books.number_of_automatic_flip_books().should == 3
    end

    it "should return 0 if there are no numbered flip-books in a directory" do
      @sid.number_of_automatic_flip_books().should == 0
    end
  end
end