require 'book'
require 'dialog'

module Flipped

  # Dialog used when starting a game.
  class GameDialog < Dialog
    public
    attr_reader :user_name
    def user_name # :nodoc:
      @user_name_field.text
    end

    public
    attr_reader :time_limit
    def time_limit # :nodoc:
      @time_limit_field.text.to_i
    end

    public
    attr_reader :screen_width
    def screen_width # :nodoc:
      @screen_width_field.text.to_i
    end

    public
    def full_screen?
      @full_screen_target.value
    end

    public
    def hard_to_quit_mode?
      @hard_to_quit_mode_target.value
    end

    protected
    def initialize(owner, title, translations, options)
      t = translations
      super(owner, title)

      t = t.game.dialog

      # User name
      FXLabel.new(@grid, t.user_name.label)

      @user_name_field = FXTextField.new(@grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|LAYOUT_FILL_X) do |widget|
        widget.text = options[:user_name]
      end

      skip_grid
      skip_grid
      
      # Time limit
      FXLabel.new(@grid, t.time_limit.label)
      @time_limit_field = FXTextField.new(@grid, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER) do |widget|
        widget.text = options[:time_limit].to_s
        widget.connect(SEL_CHANGED) do |sender, selector, text|
          # Ensure the value can't be negative.
          sender.text = (text.to_i.abs).to_s
          sender.value = sender.text
        end
      end

      skip_grid
      skip_grid

      # Resolution: X x Y
      FXLabel.new(@grid, t.resolution.label)
      resolution_frame = FXHorizontalFrame.new(@grid, :padLeft => 0, :padRight => 0, :padTop => 0, :padBottom => 0)
      @screen_width_field = FXTextField.new(resolution_frame, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER) do |widget|
        widget.text = options[:screen_width].to_s
        widget.connect(SEL_CHANGED) do |sender, selector, text|
          # Ensure the value can't be negative.
          sender.text = (text.to_i.abs).to_s
          # Show what the height would be, based on the width.
          @screen_height_field.text = (sender.text.to_i * 3 / 4).to_s
        end
      end

      FXLabel.new(resolution_frame, 'x')

      @screen_height_field = FXTextField.new(resolution_frame, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER) do |widget|
        widget.text = (@screen_width_field.text.to_i * 3 / 4).to_s
        widget.enabled = false
      end

      # Full screen?
      @full_screen_target = FXDataTarget.new(options[:full_screen])
      FXCheckButton.new(resolution_frame, t.full_screen.label, :width => 10,
                        :target => @full_screen_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.checkState = widget.target.value
      end

      skip_grid
      skip_grid

      # Hard To Quit Mode?
      @hard_to_quit_mode_target = FXDataTarget.new(options[:hard_to_quit_mode])
      FXCheckButton.new(@grid, t.hard_to_quit_mode.label, :width => 10,
                        :target => @hard_to_quit_mode_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.checkState = widget.target.value
      end
      
      skip_grid
      skip_grid
      skip_grid

    end

    protected
    def port_field(container, initial_port)
      port_field = FXTextField.new(container, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER) do |widget|
        widget.text = initial_port.to_s
        widget.connect(SEL_CHANGED) do |sender, selector, text|
          # Ensure the value can't be negative.
          sender.text = (text.to_i.abs).to_s
        end
      end

      port_field
    end

    # Text fields and a separating label in a frame: "[Address]:[Port]"
    protected
    def address_fields(container, initial_address, initial_port)
      frame = FXHorizontalFrame.new(container, :padLeft => 0, :padRight => 0, :padTop => 0, :padBottom => 0)
      address_field = FXTextField.new(frame, 15, :opts => TEXTFIELD_NORMAL) do |widget|
        widget.text = initial_address
      end

      FXLabel.new(frame, ':')
      
      port_field = port_field(frame, initial_port)

      [address_field, port_field]
    end
  end
end