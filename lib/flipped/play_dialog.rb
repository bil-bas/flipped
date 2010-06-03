require 'book'
require 'game_dialog'

module Flipped
  # Dialog to get flip-book directory and whether to broadcast when starting to monitor (also gets port).
  class PlayDialog < GameDialog
    public
    attr_reader :controller_address
    def controller_address # :nodoc:
      @controller_address_field.text
    end

    protected
    def initialize(owner, translations, options = {})
      t = translations.play_sid.dialog
      super(owner, t.title, translations, options)
     
      add_controller_address(t.controller_address, options[:controller_address])

      nil
    end
    
    protected
    def add_controller_address(t, address)
      FXLabel.new(@grid, t.label)
      @controller_address_field = address_field(@grid, address)

      skip_grid
      skip_grid
      
      nil
    end
  end
end