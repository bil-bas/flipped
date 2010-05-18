require "spec"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'flipped'))

require 'book'
include Flipped

TEMPLATE_FILES = %w[footer.php header.php index.html index.php next.png prev.png]

describe Book do
  before :each do
    @book1_dir = File.join('..', 'test_data', 'flipBooks', '00001')
    @book2_dir = File.join('..', 'test_data', 'flipBooks', '00002')
    @book3_dir = File.join('..', 'test_data', 'flipBooks', '00003')
    @output_dir = File.join('..', 'test_data', 'output', 'joined')
    @template_dir = File.join('..', 'templates')

    @template_dir_windows = "..\\templates"

    FileUtils.rm_r @output_dir if File.exists? @output_dir
    FileUtils.mkdir_p @output_dir

    @empty_book = Book.new
    @book1 = Book.new(@book1_dir)
    @book2 = Book.new(@book2_dir)
    @book3 = Book.new(@book3_dir)

    @book1_size = 8
    @book2_size = 3
    @book3_size = 1
  end

  describe "initialize() empty" do
    it "should be empty" do
      @empty_book.size.should == 0
      @empty_book.frames.size.should == 0
      @empty_book.empty?.should be_true
    end
  end

  describe "initialize(directory) from flip-book" do
    it "should return the number of frames read in from the flip-book" do
      @book1.size.should == @book1_size
    end

    it "should be empty" do
      @book1.empty?.should be_false
    end
  end

  describe "read_frame()" do
    it "should read in the appropriate frame" do
      @empty_book.send(:read_frame, @book1_dir, "00001").should == @book1[0]
    end
  end

  describe "read()" do
    it "should read in the book" do
      @empty_book.read(@book1_dir)
      @empty_book.frames.should ==  @book1.frames
    end
    
    it "should replace the original book" do
      @book1.read(@book2_dir)
      @book1.frames.should ==  @book2.frames
    end
  end

  describe "update()" do
    it "should load all frames if the book is initially empty" do
      @empty_book.update(@book1_dir).should == @book1_size
      @empty_book.frames.should ==  @book1.frames
    end

    it "should append the frames that are higher than its existing ones." do
      original_frames = @book2.frames.dup
      
      @book2.update(@book1_dir).should == @book1_size - @book2_size

      (0...@book2_size).each do |i|
        @book2[i].should == original_frames[i]
      end
    
      (@book2_size...@book1_size).each do |i|
        @book2[i].should == @book1[i]
      end
    end
  end

  describe "frame_names()" do
    it "should read in the correct list of frame names" do
      @book1.send(:frame_names, @book2_dir).should == ["00001", "00002", "00003"]
    end
  end

  describe "delete_at()" do
    it "should remove the first frame" do
      @book1.delete_at(0).should_not be_nil
      @book1.size.should == @book1_size - 1
    end

    it "should remove the last frame" do
      @book1.delete_at(@book1_size - 1).should_not be_nil
      @book1.size.should == @book1_size - 1
    end

    it "should return nil if the frame does not exist" do
      @book1.delete_at(@book1_size).should be_nil
      @book1.size.should == @book1_size
    end
  end

  describe "insert()" do
    it "should insert a single frame" do
      @book1.insert(0, "fred").should == 1
      @book1.size.should == @book1_size + 1
      @book1[0].should == "fred"
    end

    it "should insert multiple frames" do
      @book1.insert(1, "fred", "ted").should == 2
      @book1.size.should == @book1_size + 2
      @book1[1].should == "fred"
      @book1[2].should == "ted"
    end
  end

  describe "move()" do
    it "should move a single frame" do
      frame = @book1[3]
      @book1.move(3, 1).should == @book1
      @book1.size.should == @book1_size
      @book1[1].should == frame
    end
  end

  describe "append()" do
    it "should add the frames from another book" do
      @book1.append(@book2)
      @book1.size.should == @book1_size + @book2_size
    end
  end

  describe "self.valid_template_directory?()" do
    it "should return true for a valid template directory" do
      Book.valid_template_directory?(@template_dir).should be_true
    end

    it "should return true for a valid template directory, even in Windows format" do
      Book.valid_template_directory?(@template_dir_windows).should be_true
    end

    it "should return false for an invalid template directory" do
      Book.valid_template_directory?(Dir.pwd).should be_false
    end
  end

  describe "write()" do
    before :each do
      rm_rf(@output_dir) if File.exists? @output_dir
      @book1.write(@output_dir, @template_dir)
    end

    it "should create a directory identical to the original" do
      [@book1_dir, @book2_dir, @book3_dir].each do |dir|
        out_dir = dir.sub('flipBooks', 'output')
        rm_r out_dir if File.exists? out_dir
        book = Book.new(dir)
        book.write(out_dir, @template_dir)
        Dir["#{dir}/**/*.*"].each do |filename|
          File.read(filename).should == File.read(filename.sub('flipBooks', 'output'))
        end
      end
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