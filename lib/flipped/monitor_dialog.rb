require 'book'
require 'game_dialog'

module Flipped
  # Dialog to get flip-book directory and whether to broadcast when starting to monitor (also gets port).
  class MonitorDialog < GameDialog
    public
    attr_reader :flip_book_directory
    def flip_book_directory # :nodoc:
      @flip_book_directory_field.text
    end

    public
    def broadcast?
      @broadcast_target.value
    end

    public
    attr_reader :spectate_port
    def spectate_port # :nodoc:
      @spectate_port_field.text.to_i
    end

    public
    attr_reader :controller_address
    def controller_address # :nodoc:
      @controller_address_field.text
    end

    public
    attr_reader :controller_port
    def controller_port # :nodoc:
      @controller_port_field.text.to_i
    end

    protected
    def initialize(owner, translations, options = {})
      t = translations.monitor.dialog
      super(owner, t.title, translations, options)

      # Controller address.
      FXLabel.new(@grid, 'Controller address')
      @controller_address_field, @controller_port_field =
              address_fields(@grid, options[:controller_address], options[:controller_port])

      skip_grid
      skip_grid

      # Flip-book directory.
      FXLabel.new(@grid, t.flip_book_directory.label)
      @flip_book_directory_field = FXTextField.new(@grid, 40, :target => @flip_book_directory_target, :selector => FXDataTarget::ID_VALUE) do |text_field|
        text_field.editable = false
        text_field.text = options[:flip_book_directory]
        text_field.disable
      end

      Button.new(@grid, t.flip_book_directory.browse_button) do |button|
        button.connect(SEL_COMMAND) do |sender, selector, event|
          directory = FXFileDialog.getOpenDirectory(self, t.flip_book_directory.dialog.title, @flip_book_directory_field.text)
          unless directory.empty?
            if Book.valid_flip_book_directory?(directory)
              @flip_book_directory_field.text = directory
            else
              FXMessageBox.error(self, MBOX_OK, t.flip_book_directory.error.title,
                    t.flip_book_directory.error.message(directory))
            end
          end
        end
      end
      
      skip_grid

      # Broadcast?
      FXLabel.new(@grid, t.broadcast.port)

      broadcast_box = FXHorizontalFrame.new(@grid, :padLeft => 0, :padRight => 0, :padTop => 0, :padBottom => 0)     
      @spectate_port_field = port_field(broadcast_box, options[:spectate_port])
      @broadcast_target = FXDataTarget.new(options[:broadcast])
      broadcast = FXCheckButton.new(broadcast_box, t.broadcast.label, :width => 10,
                        :target => @broadcast_target, :selector => FXDataTarget::ID_VALUE)
      broadcast.checkState = @broadcast_target.value

      nil
    end
  end
end