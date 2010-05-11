require 'fox16'

require 'book'

module Flipped
  include Fox

  class OptionsDialog < FXDialogBox
    def template_directory
      @template_directory_field.text
    end

    def initialize(owner, options = {})
      super(owner, "Settings", :opts => DECOR_TITLE|DECOR_BORDER)

      # 3 columns wide.
      grid = FXMatrix.new(self, :n => 3, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X)

      # Template directory.
      FXLabel.new(grid, "Template directory")
      @template_directory_field = FXTextField.new(grid, 40) do |text_field|
        text_field.editable = false
        text_field.text = options[:template_directory]
        text_field.disable
      end

      FXButton.new(grid, "Browse...", :opts => FRAME_RAISED|FRAME_THICK) do |button|
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
  end
end