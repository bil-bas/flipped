require 'book'
require 'dialog'

module Flipped
  # Dialog to get flip-book directory and whether to broadcast when starting to monitor (also gets port).
  class MonitorDialog < Dialog
    attr_reader :flip_book_directory
    def flip_book_directory # :nodoc:
      @flip_book_directory_target.value
    end

    def broadcast?
      @broadcast_target.value
    end

    attr_reader :port
    def port # :nodoc:
      @port_target.value.to_i
    end

    attr_reader :player_name
    def player_name # :nodoc:
      @player_name_target.value
    end

    def initialize(owner, title, options = {})
      super(owner, title)

      # Template directory.
      FXLabel.new(@grid, "Flip-book directory")
      @flip_book_directory_target = FXDataTarget.new(options[:flip_book_directory])
      @flip_book_directory_field = FXTextField.new(@grid, 40, :target => @flip_book_directory_target, :selector => FXDataTarget::ID_VALUE) do |text_field|
        text_field.editable = false
        text_field.text = @flip_book_directory_target.value
        text_field.disable
      end

      Button.new(@grid, "Browse...") do |button|
        button.connect(SEL_COMMAND) do |sender, selector, event|
          directory = FXFileDialog.getOpenDirectory(self, "Select flip-book directory", @flip_book_directory_field.text)
          unless directory.empty?
          
            if Book.valid_flip_book_directory?(directory)
              @flip_book_directory_target.value = directory
            else
              FXMessageBox.error(self, MBOX_OK, "Monitor error!",
                    "Flip-book directory #{directory} is invalid. Reverting to previous setting.")

            end
          end
        end
      end
      skip_grid

      @broadcast_target = FXDataTarget.new(options[:broadcast])
      @broadcast_target.connect(SEL_COMMAND, method(:update_broadcast_group))
      broadcast = FXCheckButton.new(@grid, "Broadcast over network?", :width => 10, :opts => JUSTIFY_NORMAL|ICON_AFTER_TEXT,
                        :target => @broadcast_target, :selector => FXDataTarget::ID_VALUE)
      broadcast.checkState = @broadcast_target.value

      @broadcast_box = FXGroupBox.new(@grid, 'Broadcast options', :opts => FRAME_SUNKEN|LAYOUT_FILL_X)
      @broadcast_grid = FXMatrix.new(@broadcast_box, :n => 2, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X)
      @port_label = FXLabel.new(@broadcast_grid, "Broadcast port")
      @port_target = FXDataTarget.new(options[:port].to_s)
      @port_field = FXTextField.new(@broadcast_grid, 6, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|JUSTIFY_RIGHT|TEXTFIELD_INTEGER,
                      :target => @port_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @port_target.value
      end

      FXHorizontalFrame.new(@broadcast_box, :opts => LAYOUT_FILL_X)
      @player_name_label = FXLabel.new(@broadcast_grid, "Player name")
      @player_name_target = FXDataTarget.new(options[:player_name])
      @player_name_field = FXTextField.new(@broadcast_grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT,
                      :target => @player_name_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @player_name_target.value
      end

      update_broadcast_group
    end

  protected
    def update_broadcast_group(*args)
      [@broadcast_box, @port_label, @port_field, @player_name_label, @player_name_field].each do |widget|
        widget.enabled = @broadcast_target.value
      end
    end
  end
end