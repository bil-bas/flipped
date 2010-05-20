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

    def initialize(owner, options = {})
      super(owner, "Settings")

      # Template directory.
      FXLabel.new(@grid, "Template directory")
      @template_directory_field = FXTextField.new(@grid, 40) do |text_field|
        text_field.editable = false
        text_field.text = options[:template_directory]
        text_field.disable
      end

      Button.new(@grid, "Browse...") do |button|
        button.connect(SEL_COMMAND) do |sender, selector, event|
          directory = FXFileDialog.getOpenDirectory(self, "Select template directory", @template_directory_field.text)

          if Book.valid_template_directory?(directory)
            @template_directory_field.text = directory
          else
            dialog = FXMessageBox.new(self, "Settings error!",
                  "Template directory #{directory} is invalid. Reverting to previous setting.",
                  :opts => MBOX_OK|DECOR_TITLE|DECOR_BORDER)
            dialog.execute
          end
        end
      end

      skip_grid

      # notification sound file.
      FXLabel.new(@grid, "Notification sound")
      @notification_sound_field = FXTextField.new(@grid, 40) do |widget|
        widget.editable = false
        widget.text = options[:notification_sound]
        widget.disable
      end

      Button.new(@grid, "Browse...") do |widget|
        widget.connect(SEL_COMMAND) do |sender, selector, event|
          filename = FXFileDialog.getOpenFilename(self, "Select sound file", @notification_sound_field.text,
            "Wav files (*.wav)")

          @notification_sound_field.text = filename unless filename.empty?
        end
      end

      Button.new(@grid, "Play") do |widget|
        widget.connect(SEL_COMMAND) do |sender, selector, event|
          Sound.play(@notification_sound_field.text)
        end
      end
    end
  end
end