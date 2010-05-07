require "spec"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'flipped'))

require 'book'
include Flipped

TEMPLATE_FILES = %w[footer.php header.php index.html index.php next.png prev.png]

describe Book do
  before :each do
    @book1_dir = File.join('..', 'test_data', 'flipBooks', '00001')
    @book2_dir = File.join('..', 'test_data', 'flipBooks', '00002')
    @output_dir = File.join('..', 'test_data', 'output', 'joined')
    @template_dir = File.join('..', 'test_data', 'templates')

    @book1 = Book.new(@book1_dir)
    @book2 = Book.new(@book2_dir)
    @empty_book = Book.new

    @book1_size = 8
    @book2_size = 3
  end

  describe "initialize() empty" do
    it "should be empty" do
      @empty_book.size == 0
    end
  end

  describe "initialize(directory) from flipbook" do
    it "should return the number of frames read in from the flipbook" do
      @book1.size.should == @book1_size
    end
  end

  describe "append()" do
    it "should add the frames from another book" do
      @book1.append(@book2)
      @book1.size.should == @book1_size + @book2_size
    end
  end

  describe "write()" do
    before :each do
      rm_rf(@output_dir) if File.exists? @output_dir
      @book1.write(@output_dir, @template_dir)
    end

    it "should raise ArgumentError if output directory already exists" do
      lambda { @book1.write(@template_dir, @template_dir) }.should raise_error(ArgumentError)
    end
    
    it "should copy the frame images" do
      Dir[File.join(@book1_dir, 'images', '*.png')].each do |filename|
        base = File.basename(filename)
        File.read(File.join(@output_dir, 'images', base)).should == File.read(filename)
      end
    end

    it "should copy the correct template files" do
      TEMPLATE_FILES.each do |filename|
        File.read(File.join(@output_dir, filename)).should == File.read(File.join(@template_dir, filename))
      end
    end

    it "should write out the correct frame list php" do
      File.read(File.join(@output_dir, 'frameList.php')).should == File.read(File.join(@book1_dir, 'frameList.php'))
    end

    it "should generate identical frame html" do
      Dir[File.join(@book1_dir, 'images', '*.html')].each do |filename|
        base = File.basename(filename)
        File.read(File.join(@output_dir, 'images', base)).should == File.read(filename)
      end
    end
  end
end