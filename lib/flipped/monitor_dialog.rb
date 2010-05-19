require 'fox16'

require 'book'

module Flipped
  include Fox

  # Dialog to get flip-book directory and whether to broadcast when starting to monitor (also gets port).
  class MonitorDialog < FXDialogBox
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

    def initialize(owner, title, options = {})
      super(owner, title, :opts => DECOR_TITLE|DECOR_BORDER)

      # 3 columns wide.
      grid = FXMatrix.new(self, :n => 3, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X, :vSpacing => DEFAULT_SPACING * 3)

      # Template directory.
      FXLabel.new(grid, "Flip-book directory")
      @flip_book_directory_target = FXDataTarget.new(options[:flip_book_directory])
      @flip_book_directory_field = FXTextField.new(grid, 40, :target => @flip_book_directory_target, :selector => FXDataTarget::ID_VALUE) do |text_field|
        text_field.editable = false
        text_field.text = @flip_book_directory_target.value
        text_field.disable
      end

      FXButton.new(grid, "Browse...", :opts => FRAME_RAISED|FRAME_THICK) do |button|
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

      @broadcast_target = FXDataTarget.new(options[:broadcast])
      @broadcast_target.connect(SEL_COMMAND, method(:update_port))
      FXCheckButton.new(grid, "Broadcast over network?", :width => 10, :opts => JUSTIFY_NORMAL|ICON_AFTER_TEXT,
                        :target => @broadcast_target, :selector => FXDataTarget::ID_VALUE)

      port_frame = FXHorizontalFrame.new(grid, :opts => LAYOUT_FILL_X)
      FXLabel.new(port_frame, "Broadcast port")
      @port_target = FXDataTarget.new(options[:port].to_s)
      @port_field = FXTextField.new(port_frame, 6, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|JUSTIFY_RIGHT|TEXTFIELD_INTEGER,
                      :target => @port_target, :selector => FXDataTarget::ID_VALUE) do |port|
        port.text = @port_target.value
      end

      update_port

      # Bottom buttons
      buttons = FXHorizontalFrame.new(self,
        :opts => LAYOUT_SIDE_BOTTOM|FRAME_NONE|LAYOUT_FILL_X|PACK_UNIFORM_WIDTH,
        :padLeft => 40, :padRight => 40, :padTop => 20, :padBottom => 20)

      # Accept
      accept = FXButton.new(buttons, "&Accept",
                            :opts => FRAME_RAISED|FRAME_THICK|LAYOUT_RIGHT|LAYOUT_CENTER_Y,
                            :target => self,:selector => ID_ACCEPT)

      # Cancel
      FXButton.new(buttons, "&Cancel",
                   :opts => FRAME_RAISED|FRAME_THICK|LAYOUT_RIGHT|LAYOUT_CENTER_Y,
                   :target => self, :selector => ID_CANCEL)

      accept.setDefault
      accept.setFocus
    end

  protected
    def update_port(*args)
      if @broadcast_target.value
        @port_field.enable
      else
        @port_field.disable
      end
    end
  end
end