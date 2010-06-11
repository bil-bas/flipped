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

      add_template_directory(t.template_directory, options[:template_directory])
      add_notification_sound(t.notification_sound, options[:notification_sound])

      nil
    end

    protected
    def add_template_directory(t, initial_text)
      FXLabel.new(@grid, t.label).tipText = t.tip
      @template_directory_field = FXTextField.new(@grid, 40) do |text_field|
        text_field.editable = false
        text_field.text = initial_text
      end

      Button.new(@grid, t.browse_button) do |button|
        button.connect(SEL_COMMAND) do |sender, selector, event|
          directory = FXFileDialog.getOpenDirectory(self, t.dialog.title, @template_directory_field.text)
          unless directory.empty?
            if Book.valid_template_directory?(directory)
              @template_directory_field.text = directory
            else
              FXMessageBox.error(self, MBOX_OK, t.error.title,
                    t.error.message(directory))
            end
          end
        end
      end

      skip_grid

      nil
    end

    protected
    def add_notification_sound(t, initial_file_name)
      FXLabel.new(@grid, t.label).tipText = t.tip
      @notification_sound_field = FXTextField.new(@grid, 40) do |widget|
        widget.editable = false
        widget.text = initial_file_name
      end

      Button.new(@grid, t.browse_button) do |widget|
        widget.connect(SEL_COMMAND) do |sender, selector, event|
          filename = FXFileDialog.getOpenFilename(self, t.dialog.title, @notification_sound_field.text,
            t.dialog.pattern)
          unless filename.empty?
            @notification_sound_field.text = filename
          end
        end
      end

      Button.new(@grid, t.play_button) do |widget|
        widget.connect(SEL_COMMAND) do |sender, selector, event|
          Sound.play(@notification_sound_field.text)
        end
      end

      nil
    end
  end
end