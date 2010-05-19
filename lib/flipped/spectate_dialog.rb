require 'book'
require 'dialog'

module Flipped

  # Dialog to get flip-book directory when starting to spectate (also gets address/port).
  class SpectateDialog < Dialog
    attr_reader :flip_book_directory
    def flip_book_directory # :nodoc:
      @flip_book_directory_target.value
    end

    attr_reader :address
    def address # :nodoc:
      @address_target.value
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
          directory = FXFileDialog.getSaveDirectory(self, "Select flip-book directory", @flip_book_directory_field.text)
          unless directory.empty?

            if File.exists?(directory)
              FXMessageBox.error(self, MBOX_OK, "Spectate error!",
                    "Flip-book directory #{directory} must not exist in order to create it.")
            else
              @flip_book_directory_target.value = directory
            end
          end
        end
      end

      FXLabel.new(grid, "Address")
      address_frame = FXHorizontalFrame.new(grid, :padLeft => 0, :padRight => 0, :padTop => 0, :padBottom => 0)
      @address_target = FXDataTarget.new(options[:address].to_s)
      @address_field = FXTextField.new(address_frame, 15, :opts => TEXTFIELD_NORMAL,
                      :target => @address_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @address_target.value
      end
      
      FXLabel.new(address_frame, ':')
      @port_target = FXDataTarget.new(options[:port].to_s)
      @port_field = FXTextField.new(address_frame, 6, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|JUSTIFY_RIGHT|TEXTFIELD_INTEGER,
                      :target => @port_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @port_target.value
      end

      FXLabel.new(grid, '')
      @player_name_label = FXLabel.new(grid, "Player name")
      @player_name_target = FXDataTarget.new(options[:player_name])
      @player_name_field = FXTextField.new(grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|LAYOUT_FILL_X,
                      :target => @player_name_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @player_name_target.value
      end
    end
  end
end