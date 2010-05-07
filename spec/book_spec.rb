require "spec"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'flipped'))

require 'book'
include Flipped

describe Book do
  before :each do
    @book1_path = File.join('..', 'test_data', 'flipBooks', '00001')
    @book2_path = File.join('..', 'test_data', 'flipBooks', '00002')
    @output_dir = File.join('..', 'test_data', 'output', 'joined')
    @template_dir = File.join('..', 'test_data', 'templates')

    @joined_frame_list = <<END_PHP
<?php $frameList = array( "00001", "00002", "00003", "00004", "00005", "00006", "00007", "00008", "00009", "00010", "00011" ); ?>
END_PHP

    @book1 = Book.new(@book1_path)
    @book2 = Book.new(@book2_path)

    @book1_size = 8
    @book2_size = 3
  end

 describe "frames()" do
    it "should contain a list of frames read from the frame list file" do
      @book1.frames.size.should == @book1_size
    end
  end

  describe "size()" do
    it "should return the number of frames currently stored" do
      @book1.size.should == @book1_size
    end
  end

  describe "append!()" do
    it "should add the frames from another book" do
      @book1.append(@book2)
      @book1.size.should == @book1_size + @book2_size
    end
  end

  describe "write()" do
    before :each do
      rm_rf(@output_dir) if File.exists? @output_dir
      @book1.append(@book2)
      @book1.write(@output_dir, @template_dir)
    end
    
    it "should write out the correct frame list" do
      File.read(File.join(@output_dir, 'frameList.php')).should == @joined_frame_list
    end
  end
end