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

    attr_reader :user_name
    def user_name # :nodoc:
      @user_name_target.value
    end

    attr_reader :time_limit
    def time_limit # :nodoc:
      @time_limit_target.value.to_i
    end

    def initialize(owner, translation, options = {})
      t = translation
      super(owner, t.title)

      # Flip-book directory.
      FXLabel.new(@grid, t.flip_book_directory.label)
      @flip_book_directory_target = FXDataTarget.new(options[:flip_book_directory])
      @flip_book_directory_field = FXTextField.new(@grid, 40, :target => @flip_book_directory_target, :selector => FXDataTarget::ID_VALUE) do |text_field|
        text_field.editable = false
        text_field.text = @flip_book_directory_target.value
        text_field.disable
      end

      Button.new(@grid, t.flip_book_directory.browse_button) do |button|
        button.connect(SEL_COMMAND) do |sender, selector, event|
          directory = FXFileDialog.getSaveFilename(self, t.flip_book_directory.dialog.title, @flip_book_directory_field.text)
          unless directory.empty?
            if File.exists?(directory)
              FXMessageBox.error(self, MBOX_OK, t.flip_book_directory.error.title,
                    t.flip_book_directory.error.message(directory))
            else
              @flip_book_directory_target.value = directory
            end
          end
        end
      end
      skip_grid

      # Time limit
      FXLabel.new(@grid, t.time_limit)
      @time_limit_target = FXDataTarget.new(options[:time_limit].to_s)
      FXTextField.new(@grid, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER,
                      :target => @time_limit_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @time_limit_target.value
      end

      skip_grid
      skip_grid

      # IP Address
      FXLabel.new(@grid, t.ip_address.label)
      address_frame = FXHorizontalFrame.new(@grid, :padLeft => 0, :padRight => 0, :padTop => 0, :padBottom => 0)
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
      skip_grid

      # User name
      skip_grid
      @user_name_label = FXLabel.new(@grid, t.spectator_name.label)
      @user_name_target = FXDataTarget.new(options[:user_name])
      @user_name_field = FXTextField.new(@grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|LAYOUT_FILL_X,
                      :target => @user_name_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @user_name_target.value
      end

    end
  end
end