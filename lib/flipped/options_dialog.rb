require 'book'
require 'dialog'
require 'sound'

module Flipped
  class OptionsDialog < Dialog
    def template_directory
      @template_directory_field.text
    end

    def notification_sound
      @notification_sound_field.text
    end

    def initialize(owner, translations, options = {})
      t = translations
      super(owner, t.title, t.accept_button, t.cancel_button)

      # Template directory.
      FXLabel.new(@grid, t.template_directory.label)
      @template_directory_field = FXTextField.new(@grid, 40) do |text_field|
        text_field.editable = false
        text_field.text = options[:template_directory]
        text_field.disable
      end

      Button.new(@grid, t.template_directory.browse_button) do |button|
        button.connect(SEL_COMMAND) do |sender, selector, event|
          directory = FXFileDialog.getOpenDirectory(self, t.template_directory.dialog.title, @template_directory_field.text)
          unless directory.empty?
            if Book.valid_template_directory?(directory)
              @template_directory_field.text = directory
            else
              FXMessageBox.error(self, MBOX_OK, t.template_directory.error.title,
                    t.template_directory.error.message(directory))
            end
          end
        end
      end

      skip_grid

      # notification sound file.
      FXLabel.new(@grid, t.notification_sound.label)
      @notification_sound_field = FXTextField.new(@grid, 40) do |widget|
        widget.editable = false
        widget.text = options[:notification_sound]
        widget.disable
      end

      Button.new(@grid, t.notification_sound.browse_button) do |widget|
        widget.connect(SEL_COMMAND) do |sender, selector, event|
          filename = FXFileDialog.getOpenFilename(self, t.notification_sound.dialog.title, @notification_sound_field.text,
            t.notification_sound.dialog.pattern)
          unless filename.empty?
            @notification_sound_field.text = filename
          end
        end
      end

      Button.new(@grid, t.notification_sound.play_button) do |widget|
        widget.connect(SEL_COMMAND) do |sender, selector, event|
          Sound.play(@notification_sound_field.text)
        end
      end
    end
  end
end