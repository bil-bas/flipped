require 'fox16'
include Fox

require 'button'

require 'book'

module Flipped
  class Dialog < FXDialogBox

    TEXT_COLUMNS = 40

    protected
    def initialize(owner, title, accept, cancel = nil)
      super(owner, title, :opts => DECOR_TITLE|DECOR_BORDER)

      # 4 columns wide.
      @grid = FXMatrix.new(self, :n => 4, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X, :hSpacing => 8, :vSpacing => 20)

      FXHorizontalSeparator.new(self, :padTop => 10)

      # Bottom buttons
      buttons = FXHorizontalFrame.new(self,
        :opts => LAYOUT_SIDE_BOTTOM|FRAME_NONE|LAYOUT_FILL_X|PACK_UNIFORM_WIDTH,
        :padLeft => 40, :padRight => 40, :padTop => 10, :padBottom => 10)

      # Accept
      Button.new(buttons, accept,
                            :opts => LAYOUT_RIGHT|LAYOUT_CENTER_Y,
                            :target => self,:selector => ID_ACCEPT) do |widget|
        widget.setDefault
        widget.setFocus
      end

      if cancel
        Button.new(buttons, cancel,
                     :opts => LAYOUT_RIGHT|LAYOUT_CENTER_Y,
                     :target => self, :selector => ID_CANCEL)
      end

      nil
    end

    # Skip a grid cell.
    protected
    def skip_grid
      FXLabel.new(@grid, '')

      nil
    end

    # Letter, number, _, &, -, ', ", %, ., ,, space
    protected
    def verify_text(sender, selector, text)
       if text =~ /^[A-Za-z0-9_\&-'"%., ]*$/
        false
      else
        true
      end
    end

    # Letter, number, _
    protected
    def verify_name(sender, selector, text)
       if text =~ /^[A-Za-z0-9_]*$/
        false
      else
        true
      end
    end

    # Internet address.
    protected
    def verify_address(sender, selector, text)
       if text =~ /^[A-Za-z0-9_\-\.]*$/
        false
      else
        true
      end
    end

    # 1..65535 required in port.
    protected
    def verify_port(sender, selector, text)
      if text =~ /^(\d*)$/
        not (1..65535).include?($1.to_i)
      else
        true
      end
    end

    protected
    def verify_positive_number(sender, selector, text)
      if text =~ /^(\d*)$/
        $1.to_i < 1
      else
        true
      end
    end
  end
end