require 'fileutils'

module Flipped
  include FileUtils
  
  class Book
    FRAME_LIST_FILE = 'frameList.php'

    FRAME_LIST_PATTERN = /array\(\s+"(.*)"\s+\)/

    FRAME_LIST_TEMPLATE = '<?php $frameList = array( $FRAME_NUMBERS$ ); ?>'

    TEMPLATE_FILES = %w[footer.php header.php index.html index.php next.png prev.png]

    NEXT_BUTTON_HTML = 'nextButton.html'
    PREVIOUS_BUTTON_HTML = 'prevButton.html'
    FRAME_TEMPLATE_HTML = 'x.html'
    PRELOAD_NEXT_HTML = 'preloadNext.html'

    def initialize(directory)
      frame_list_text = File.open(File.join(directory, FRAME_LIST_FILE)) do |file|
        file.read
      end


      frame_list_text =~ FRAME_LIST_PATTERN
      frame_names =  $1.split(/",\s+"/)
      frame_numbers = frame_names.map { |s| s.to_i }
      @frames = frame_names.inject([]) do |list, name|
        data = File.open(File.join(directory, 'images', "#{name}.png"), "rb") do |file|
          file.read   
        end
        list.push data
      end
    end

    def size
      @frames.size
    end

    def frames
      @frames.dup
    end

    # Adds another book to the end of this one.
    def append(book)
      @frames += book.frames
    end

    def write(out_dir, template_dir)
      if File.exists?(out_dir)
        raise RuntimeError.new("Directory already exists: #{out_dir}")
      end

      images_dir = File.join(out_dir, 'images')
      mkdir_p(images_dir)

      frame_numbers = (1..@frames.size).to_a.map {|i| sprintf("%05d", i) }

      # Write out the images and html pages.
      @frames.each_with_index do |image_data, i|
        File.open(File.join(images_dir, "#{frame_numbers[i]}.png"), "wb") do |file|
          file.write(image_data)
        end

        File.open(File.join(images_dir, "#{frame_numbers[i]}.html"), "w") do |file|
          file.puts ""
        end
      end
      
      frame_numbers_quoted = frame_numbers.map {|s| "\"#{s}\""}

      # Write out the frameList file
      File.open(File.join(out_dir, FRAME_LIST_FILE), "w") do |file|
        file.puts(FRAME_LIST_TEMPLATE.sub("$FRAME_NUMBERS$", frame_numbers_quoted.join(', ')))
      end

      # Copy template files.
      TEMPLATE_FILES.each do |template|
        cp(File.join(template_dir, template), File.join(out_dir, template))
      end
    end
  end
end