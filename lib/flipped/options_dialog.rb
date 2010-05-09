require 'fox16'

require 'book'

module Flipped
  include Fox

  class OptionsDialog < FXDialogBox

    MAX_INTERVAL = 30
    NUM_INTERVALS_SEEN = 20

    def slide_show_interval
      @slide_show_interval_field.getItemData(@slide_show_interval_field.currentItem)
    end

    def slide_show_interval=(value)
      @slide_show_interval_field.currentItem = value - 1
    end

    def template_dir
      @template_dir_field.text
    end

    def template_dir=(value)
      @template_dir_field.text = value
    end

    def initialize(owner)
      super(owner, "Options", :opts => DECOR_TITLE|DECOR_BORDER|LAYOUT_FIX_WIDTH, :width => 600)

      grid = FXMatrix.new(self, :n => 3, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X)

      # Slide-show duration.
      FXLabel.new(grid, "Slide-show duration (secs)")
      @slide_show_interval_field = FXComboBox.new(grid, 10) do |combo|
        (1..MAX_INTERVAL).each {|i| combo.appendItem(i.to_s, i) }
        combo.editable = false
        combo.numVisible = NUM_INTERVALS_SEEN
      end
      FXLabel.new(grid, "")     

      # Template directory.
      FXLabel.new(grid, "Template directory")
      @template_dir_field = FXLabel.new(grid, '', :opts => JUSTIFY_LEFT)
      FXButton.new(grid, "Browse...", :opts => FRAME_RAISED|FRAME_THICK).connect(SEL_COMMAND) do |sender, selector, event|
        directory = FXFileDialog.getOpenDirectory(self, "Select template directory", @template_dir_field.text)
        
        if Book.valid_template_directory?(directory)
          @template_dir_field.text = directory
        else
          dialog = FXMessageBox.new(self, "Settings error!",
                "Template directory #{directory} is invalid. Reverting to previous setting.",
                :opts => MBOX_OK|DECOR_TITLE|DECOR_BORDER)
          dialog.execute
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