require 'fox16'

require 'book'

module Flipped
  include Fox

  class Dialog < FXDialogBox

    def initialize(owner, title)
      super(owner, title, :opts => DECOR_TITLE|DECOR_BORDER)

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