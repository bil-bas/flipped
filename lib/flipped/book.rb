require 'fileutils'

module Flipped
  include FileUtils

  # A flip-book for SleepIsDeath.
  #
  # Enables reading/editing/writing flipbooks.
  class Book
    FRAME_LIST_FILE = 'frameList.php'

    FRAME_LIST_PATTERN = /array\(\s*"(.*)"\s*\)/

    FRAME_LIST_TEMPLATE = '<?php $frameList = array( $FRAME_NUMBERS$ ); ?>'

    TEMPLATE_FILES = %w[footer.php header.php index.html index.php next.png prev.png]

    NEXT_BUTTON_HTML = 'nextButton.html'
    PREVIOUS_BUTTON_HTML = 'prevButton.html'
    FRAME_TEMPLATE_HTML = 'x.html'
    PRELOAD_NEXT_HTML = 'preloadNext.html'

    # Create a new book, optionally from an existing flipbook directory.
    #
    # === Parameters
    # directory:: Flipbook directory to read from [String]
    def initialize(directory = nil)
      if directory
        # Read in framelists in php format and extract the numbers.
        frame_list_text = File.open(File.join(directory, FRAME_LIST_FILE)) do |file|
          file.read
        end

        frame_list_text =~ FRAME_LIST_PATTERN
        frame_names =  $1.split(/",\s+"/)
        frame_numbers = frame_names.map { |s| s.to_i }

        # Load in images in order they were in the framelist file.
        @frames = frame_names.inject([]) do |list, name|
          data = File.open(File.join(directory, 'images', "#{name}.png"), "rb") do |file|
            file.read
          end
          list.push data
        end
      else
        @frames = []
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

      images_dir = File.join(out_dir, 'images')
      mkdir_p(images_dir)

      frame_numbers = (1..@frames.size).to_a.map {|i| sprintf("%05d", i) }

      # Load templates.
      frame_template_html = File.open(File.join(template_dir, FRAME_TEMPLATE_HTML)) {|f| f.read }
      previous_html = File.open(File.join(template_dir, PREVIOUS_BUTTON_HTML)) {|f| f.read }
      next_html = File.open(File.join(template_dir, NEXT_BUTTON_HTML)) {|f| f.read }
      preload_html = File.open(File.join(template_dir, PRELOAD_NEXT_HTML)) {|f| f.read }

      # Write out the images and html pages.
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
          file.print html.gsub("\n\n", "\n") # Jason spams newlines for some reason :)
        end
      end
      
      frame_numbers_quoted = frame_numbers.map {|s| "\"#{s}\""}

      # Write out the frameList file
      File.open(File.join(out_dir, FRAME_LIST_FILE), "w") do |file|
        file.print(FRAME_LIST_TEMPLATE.sub("$FRAME_NUMBERS$", frame_numbers_quoted.join(', ')))
      end

      # Copy template files.
      TEMPLATE_FILES.each do |template|
        cp(File.join(template_dir, template), File.join(out_dir, template))
      end

      self
    end
  end
end