require 'fileutils'

module Flipped
  include FileUtils

  # A flip-book for SleepIsDeath.
  #
  # Enables reading/editing/writing flip-books.
  class Book
    FRAME_LIST_FILE = 'frameList.php'

    FRAME_LIST_PATTERN = /array\(\s*"(.*)"\s*\)/

    FRAME_LIST_TEMPLATE = '<?php $frameList = array( $FRAME_NUMBERS$ ); ?>'

    NEXT_BUTTON_HTML = 'nextButton.html'
    PREVIOUS_BUTTON_HTML = 'prevButton.html'
    FRAME_TEMPLATE_HTML = 'x.html'
    PRELOAD_NEXT_HTML = 'preloadNext.html'

    HTML_TEMPLATE_FILES = [NEXT_BUTTON_HTML, PREVIOUS_BUTTON_HTML, FRAME_TEMPLATE_HTML, PRELOAD_NEXT_HTML]
    ALL_TEMPLATE_FILES = HTML_TEMPLATE_FILES + [FRAME_LIST_FILE]

    IMAGES_DIR = 'images'
    FLIP_BOOK_DIRECTORY_FORMAT = "%05d"

    # Create a new book, optionally from an existing flipbook directory.
    #
    # === Parameters
    # directory:: Flip-book directory to read from [String]
    def initialize(directory = nil)
      if directory
        read(directory)
      else
        @frames = []
      end
    end

    # Read all frames from a directory, overwriting any frames we already have.
    #
    # === Parameters
    # +directory+:: Flip-book directory to load from [String].
    #
    # Returns: Number of frames actually loaded [Integer]
    def read(directory)
      begin
        # Load in images in order they were in the frame-list file.
        @frames = frame_names(directory).inject([]) do |list, name|
          list.push read_frame(directory, name)
        end
      rescue => ex
        raise IOError.new("Failed to read frames from flip-book at '#{directory}'")
      end

      size
    end

    # Update frames from a directory, loading only those frames that are not already loaded.
    # Note: this does not check if the frames already loaded are correct!
    #
    # === Parameters
    # +directory+:: Flip-book directory to load from [String].
    #
    # Returns: Number of frames actually loaded [Integer]
    def update(directory)
      names = frame_names(directory)
      if names.size > size
        num = names.size - size
        (size...names.size).each do |i|
          frame = read_frame(directory, names[i])
          # Ensure that empty frames (not properly saved) are ignored.
          return (i - size) if frame.nil? or frame.empty?
          @frames.push frame
        end
        num
      else
        0
      end
    end

    # Number of frames in the book [Integer]
    attr_reader :size
    def size # :nodoc:
      @frames.size
    end

    # Get a single frame.
    #
    # === Parameters
    # index:: Position of frame to look at [Integer]
    #
    # Returns: Raw data for a specific frame (ORIGINAL, NOT A COPY).
    def [](index)
      @frames[index]
    end

    # List of image data strings [Array of String]
    attr_reader :frames
    def frames() #:nodoc:
      @frames.dup
    end

    # Is the book empty? 
    def empty?
      @frames.size == 0
    end

    # Adds another book to the end of this one.
    #
    # === Parameters
    # book:: Other book to append to this one [Book]
    #
    # Returns: self
    def append(book)
      @frames += book.frames
      self
    end

    # Delete a single frame from the Book.
    #
    # === Parameters
    # index:: Position of frame to delete [Integer]
    #
    # Returns: Index deleted if it existed, else nil [Integer or nil]
    def delete_at(index)
      @frames.delete_at(index)
    end

    # Insert a frame or frames into the book.
    #
    # === Parameters
    # index::  Position of frame to insert before [Integer]
    # frames_to_insert:: Any number of frame data strings to add [String]
    #
    # Returns number of frames inserted [Integer].
    def insert(index, *frames_to_insert)
      @frames.insert(index, *frames_to_insert)
      frames_to_insert.size
    end

    # Moves a frame within the Book.
    #
    # === Parameters
    # remove_from:: Position of frame to move [Integer]
    # insert_at:: Frame position to insert before [Integer]
    #
    # Returns: self
    def move(remove_from, insert_at)
      @frames.insert(insert_at, @frames.delete_at(remove_from))
      self
    end

    # Write out a new flipbook directory.
    #
    # Raises ArgumentError if the directory already exists.
    #
    # === Parameters
    # out_dir:: Directory of new flipbook [String]
    # template_dir:: Directory where standard template files are stored [String]
    #
    # Returns: self
    def write(out_dir, template_dir)
      if File.exists?(out_dir)
        raise ArgumentError.new("Directory already exists: #{out_dir}")
      end

      images_dir = File.join(out_dir, IMAGES_DIR)

      frame_numbers = (1..@frames.size).to_a.map {|i| sprintf(FLIP_BOOK_DIRECTORY_FORMAT, i) }

      # Load templates.
      frame_template_html = File.open(File.join(template_dir, FRAME_TEMPLATE_HTML)) {|f| f.read }
      previous_html = File.open(File.join(template_dir, PREVIOUS_BUTTON_HTML)) {|f| f.read }
      next_html = File.open(File.join(template_dir, NEXT_BUTTON_HTML)) {|f| f.read }
      preload_html = File.open(File.join(template_dir, PRELOAD_NEXT_HTML)) {|f| f.read }

      # Write out the images and html pages.
      mkdir_p(images_dir)
      @frames.each_with_index do |image_data, i|
        File.open(File.join(images_dir, "#{frame_numbers[i]}.png"), "wb") do |file|
          file.write(image_data)
        end

        # Do replacement in template files.
        html = frame_template_html.dup

        html.sub!('#PREV', i > 0 ? previous_html : '')
        html.sub!('#NEXT', i < (@frames.size - 1) ? next_html : '')
        html.sub!('#PRELOAD', i < (@frames.size - 1) ? preload_html : '')

        html.gsub!('#W', frame_numbers[(i - 1).modulo(@frames.size)]) # previous file number
        html.gsub!('#X', frame_numbers[i]) # current file number
        html.gsub!('#Y', frame_numbers[(i + 1).modulo(@frames.size)]) # next file number
        
        File.open(File.join(images_dir, "#{frame_numbers[i]}.html"), "w") do |file|
          file.print html.gsub(/[\r\n]\n/, "\n") # Jason spams newlines for some reason :)
        end
      end
      
      frame_numbers_quoted = frame_numbers.map {|s| "\"#{s}\""}

      # Write out the frameList file
      File.open(File.join(out_dir, FRAME_LIST_FILE), "w") do |file|
        file.print(FRAME_LIST_TEMPLATE.sub("$FRAME_NUMBERS$", frame_numbers_quoted.join(', ')))
      end

      # Copy all other files and directories across intact.
      template_files_pattern = File.join(template_dir.split("\\") + ["*"]) # Unwindows the path.
      Dir[template_files_pattern].each do |filename|
        base_name = File.basename(filename)
        unless ALL_TEMPLATE_FILES.include?(base_name)
          cp_r(filename, out_dir)
        end
      end

      self
    end

    # Is the specified template directory valid. That is, does it include all the files
    # absolutely required to generate a flip-book?
    #
    # === Parameters
    # directory:: Directory to check [String]
    #
    # Returns: true if the directory is valid, otherwise false.
    def self.valid_template_directory?(directory)
       HTML_TEMPLATE_FILES.each do |template|
        return false unless File.exists?(File.join(directory, template))
      end

      true
    end

    # Is the specified flip-book directory valid. That is, does it include all the files
    # absolutely required to load a flip-book?
    #
    # === Parameters
    # directory:: Directory to check [String]
    #
    # Returns: true if the directory is valid, otherwise false.
    def self.valid_flip_book_directory?(directory)
      File.exists?(File.join(directory, FRAME_LIST_FILE)) and File.directory?(File.join(directory, IMAGES_DIR))
    end

    # Find the path of the latest flip-book directory created by the game.
    #
    # === Parameters
    # +directory+:: flip-book directory (that is SiD/flipBooks) [String]
    #
    # Returns: path to last flip-book or nil if none exist [String or nil)
    def self.latest_automatic_directory(directory)
      i = 1
      last = nil
      loop do
        current = File.join(directory, sprintf(FLIP_BOOK_DIRECTORY_FORMAT, i))
        break unless File.directory?(current)
        last = current
        i += 1
      end

      last
    end
    
  protected
    # Read all frames from a directory, overwriting any frames we already have.
    #
    # === Parameters
    # +directory+:: Flip-book directory to load from [String].
    # +name+:: Name of frame to load [String].
    #
    # Returns: Frame data [String]
    def read_frame(directory, name)
      File.open(File.join(directory, IMAGES_DIR, "#{name}.png"), "rb") do |file|
        file.read
      end
    end

    # Get frame-names list from a flip-book directory
    #
    # === Parameters
    # +directory+:: Flip-book directory to load from.
    #
    # Returns: Names of frames [Array of String]
    def frame_names(directory)
      # Read in frame-lists in php format and extract the numbers.
      frame_list_text = File.open(File.join(directory, FRAME_LIST_FILE)) do |file|
        file.read
      end

      frame_list_text =~ FRAME_LIST_PATTERN

      $1.split(/"\s*,\s+"/)
    end
  end
end