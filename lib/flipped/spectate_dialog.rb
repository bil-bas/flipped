require 'book'
require 'game_dialog'

module Flipped

  # Dialog to get flip-book directory when starting to spectate (also gets address/port).
  class SpectateDialog < GameDialog
    public
    attr_reader :flip_book_directory
    def flip_book_directory # :nodoc:
      @flip_book_directory_field.text
    end

    public
    attr_reader :address
    def address # :nodoc:
      @address_field.text
    end

    public
    attr_reader :port
    def port # :nodoc:
      @port_field.text.to_i
    end

    protected
    def initialize(owner, translations, options = {})
      t = translations.spectate.dialog
      super(owner, t.title, translations, options)
      
      # Flip-book directory.
      FXLabel.new(@grid, t.flip_book_directory.label)
      @flip_book_directory_field = FXTextField.new(@grid, 40, :target => @flip_book_directory_target, :selector => FXDataTarget::ID_VALUE) do |text_field|
        text_field.editable = false
        text_field.text = options[:flip_book_directory]
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
              @flip_book_directory_text.text = directory
            end
          end
        end
      end
      skip_grid

      # IP Address
      FXLabel.new(@grid, t.ip_address.label)
      @address_field, @port_field = address_fields(@grid, options[:address], options[:port])
      skip_grid
    end
  end
end