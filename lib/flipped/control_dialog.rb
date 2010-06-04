require 'book'
require 'game_dialog'

module Flipped

  # Dialog to get flip-book directory when starting to spectate (also gets address/port).
  class ControlDialog < GameDialog
    public
    attr_reader :story_name
    def story_name # :nodoc:
      @story_name_field.text
    end

    protected
    def initialize(owner, translations, options = {})
      t = translations.control_sid.dialog
      super(owner, t.title, translations, options)

      add_story_name(t.story_name, options[:story_name])

      nil
    end

    protected
    def add_story_name(t, name)
      FXLabel.new(@grid, t.label)

      @story_name_field = FXTextField.new(@grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|LAYOUT_FILL_X) do |widget|
        widget.text = name
        widget.connect(SEL_VERIFY, method(:verify_text))
      end

      skip_grid
      skip_grid

      nil
    end
  end
end