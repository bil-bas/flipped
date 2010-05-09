require 'fox16'

module Flipped
  include Fox

  class OptionsDialog < FXDialogBox

    def slide_show_interval
      @slide_show_interval_field.text.to_i
    end

    def slide_show_interval=(value)
      @slide_show_interval_field.text = value.to_s
    end

    def template_dir
      @template_dir_field.text
    end

    def template_dir=(value)
      @template_dir_field.text = value
    end

    def initialize(owner)
      super(owner, "Options", DECOR_TITLE|DECOR_BORDER)

      grid = FXMatrix.new(self, :n => 3, :opts => MATRIX_BY_COLUMNS)

      # Slide-show duration.
      FXLabel.new(grid, "Slide-show duration")
      @slide_show_interval_field = FXTextField.new(grid, 10, :opts => TEXTFIELD_NORMAL|LAYOUT_SIDE_RIGHT)
      FXLabel.new(grid, "")

      # Template directory.
      FXLabel.new(grid, "Template directory")
      @template_dir_field = FXTextField.new(grid, 50)
      FXButton.new(grid, "Browse...", :opts => FRAME_RAISED|FRAME_THICK).connect(SEL_COMMAND) do |sender, selector, event|
        @template_dir_field.text = FXFileDialog.getOpenDirectory(self, "Select template directory", @template_dir_field.text)
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