require 'fox16'

require 'button'

require 'book'

module Flipped
  include Fox

  class Dialog < FXDialogBox

    def initialize(owner, title)
      super(owner, title, :opts => DECOR_TITLE|DECOR_BORDER)

      # 4 columns wide.
      @grid = FXMatrix.new(self, :n => 4, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X, :hSpacing => 8, :vSpacing => 8)

      FXHorizontalSeparator.new(self, :padTop => 10)

      # Bottom buttons
      buttons = FXHorizontalFrame.new(self,
        :opts => LAYOUT_SIDE_BOTTOM|FRAME_NONE|LAYOUT_FILL_X|PACK_UNIFORM_WIDTH,
        :padLeft => 40, :padRight => 40, :padTop => 10, :padBottom => 10)

      # Accept
      accept = Button.new(buttons, "&Accept",
                            :opts => LAYOUT_RIGHT|LAYOUT_CENTER_Y,
                            :target => self,:selector => ID_ACCEPT)

      # Cancel
      Button.new(buttons, "&Cancel",
                   :opts => LAYOUT_RIGHT|LAYOUT_CENTER_Y,
                   :target => self, :selector => ID_CANCEL)

      accept.setDefault
      accept.setFocus
    end

    # Skip a grid cell.
    def skip_grid
      FXLabel.new(@grid, '')
    end
  end
end