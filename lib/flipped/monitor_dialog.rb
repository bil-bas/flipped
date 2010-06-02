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

    attr_reader :user_name
    def user_name # :nodoc:
      @user_name_target.value
    end

    attr_reader :time_limit
    def time_limit # :nodoc:
      @time_limit_target.value.to_i
    end

    def initialize(owner, translations, options = {})
      t = translations

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
          directory = FXFileDialog.getOpenDirectory(self, t.flip_book_directory.dialog.title, @flip_book_directory_field.text)
          unless directory.empty?
            if Book.valid_flip_book_directory?(directory)
              @flip_book_directory_target.value = directory
            else
              FXMessageBox.error(self, MBOX_OK, t.flip_book_directory.error.title,
                    t.flip_book_directory.error.message(directory))
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

      # Broadcast?
      skip_grid

      @broadcast_target = FXDataTarget.new(options[:broadcast])
      @broadcast_target.connect(SEL_COMMAND, method(:update_broadcast_group))
      broadcast = FXCheckButton.new(@grid, t.broadcast.label, :width => 10, :opts => JUSTIFY_NORMAL|ICON_AFTER_TEXT,
                        :target => @broadcast_target, :selector => FXDataTarget::ID_VALUE)
      broadcast.checkState = @broadcast_target.value

      @broadcast_box = FXGroupBox.new(@grid, t.broadcast.group, :opts => FRAME_SUNKEN|LAYOUT_FILL_X)
      @broadcast_grid = FXMatrix.new(@broadcast_box, :n => 2, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X)
      @port_label = FXLabel.new(@broadcast_grid, t.broadcast.port)
      @port_target = FXDataTarget.new(options[:port].to_s)
      @port_field = FXTextField.new(@broadcast_grid, 6, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|JUSTIFY_RIGHT|TEXTFIELD_INTEGER,
                      :target => @port_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @port_target.value
      end

      FXHorizontalFrame.new(@broadcast_box, :opts => LAYOUT_FILL_X)
      @user_name_label = FXLabel.new(@broadcast_grid, t.broadcast.name)
      @user_name_target = FXDataTarget.new(options[:user_name])
      @user_name_field = FXTextField.new(@broadcast_grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT,
                      :target => @user_name_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @user_name_target.value
      end

      update_broadcast_group      
    end

  protected
    def update_broadcast_group(*args)
      [@broadcast_box, @port_label, @port_field, @user_name_label, @user_name_field].each do |widget|
        widget.enabled = @broadcast_target.value
      end
    end
  end
end