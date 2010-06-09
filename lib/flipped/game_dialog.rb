require 'sid'
require 'dialog'
require 'button'

module Flipped

  # Dialog used when starting a game.
  class GameDialog < Dialog
    public
    attr_reader :user_name
    def user_name # :nodoc:
      @user_name_field.text
    end

    public
    attr_reader :flip_book_pattern
    def flip_book_pattern # :nodoc:
      @flip_book_pattern_field.text
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
    attr_reader :screen_height
    def screen_height # :nodoc:
      @screen_height_field.text.to_i
    end

    public
    def full_screen?
      @full_screen_target.value
    end

    public
    def hard_to_quit_mode?
      @hard_to_quit_mode_target.value
    end

    public
    attr_reader :sid_directory
    def sid_directory # :nodoc:
      @sid_directory_field.text
    end

    public
    attr_reader :spectate_port
    def spectate_port # :nodoc:
      @spectate_port_field.text.to_i
    end

    protected
    def initialize(owner, title, translations, options)
      t = translations
      super(owner, title)

      t = t.game.dialog

      add_sid_directory(t.sid_directory, options[:sid_directory])
      add_flip_book_pattern(t.flip_book_pattern, options[:flip_book_pattern])
      add_user_name(t.user_name, options[:user_name])
      add_time_limit(t.time_limit, options[:time_limit])
      add_resolution(t, options[:screen_width], options[:screen_height], options[:full_screen])
      add_hard_to_quit_mode(t.hard_to_quit_mode, options[:hard_to_quit_mode])
      add_spectator_port(t.spectate_port, options[:spectate_port])
      
      nil
    end

    protected
    def add_flip_book_pattern(t, pattern)
      FXLabel.new(@grid, t.label)

      @flip_book_pattern_field = FXTextField.new(@grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|LAYOUT_FILL_X) do |widget|
        widget.text = pattern
        widget.connect(SEL_VERIFY, method(:verify_text))
      end

      Button.new(@grid, t.default_button, :opts => LAYOUT_FILL_X).connect(SEL_COMMAND) do |sender, selector, event|
        @flip_book_pattern_field.text = DEFAULT_FLIP_BOOK_PATTERN.to_s
      end
      
      skip_grid

      nil
    end

    protected
    def add_user_name(t, initial)
      FXLabel.new(@grid, t.label)

      @user_name_field = FXTextField.new(@grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|LAYOUT_FILL_X) do |widget|
        widget.text = initial
        widget.connect(SEL_VERIFY, method(:verify_name))
      end

      skip_grid
      skip_grid

      nil
    end

    protected
    def add_time_limit(t, initial)
      FXLabel.new(@grid, t.label)
      @time_limit_field = FXTextField.new(@grid, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER) do |widget|
        widget.text = initial.to_s
        widget.connect(SEL_VERIFY, method(:verify_positive_number))
      end

      Button.new(@grid, t.default_button, :opts => LAYOUT_FILL_X).connect(SEL_COMMAND) do |sender, selector, event|
        @time_limit_field.text = DEFAULT_TIME_LIMIT.to_s
      end

      skip_grid

      nil
    end

    # Resolution: width X height and full screen
    protected
    def add_resolution(t, width, height, full_screen)
      FXLabel.new(@grid, t.resolution.label)
      
      frame = FXHorizontalFrame.new(@grid, :padLeft => 0, :padRight => 0, :padTop => 0, :padBottom => 0)

      # Screen width.
      @screen_width_field = FXTextField.new(frame, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER) do |widget|
        widget.text = width.to_s
        widget.connect(SEL_VERIFY, method(:verify_positive_number))
        widget.connect(SEL_CHANGED) do |sender, selector, text|
          # Show what the height would be, based on the width.
          calculate_screen_height unless full_screen
        end
      end

      FXLabel.new(frame, 'x')

      # Screen height.
      @screen_height_field = FXTextField.new(frame, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER) do |widget|
        widget.text = height.to_s
        widget.enabled = full_screen
        widget.connect(SEL_VERIFY, method(:verify_positive_number))
      end

      # Full screen?
      @full_screen_target = FXDataTarget.new(full_screen)
      @full_screen_target.connect(SEL_COMMAND) do |sender, selector, event|
        @screen_height_field.enabled = sender.value
        calculate_screen_height unless sender.value
      end
      FXCheckButton.new(frame, t.full_screen.label,
                        :target => @full_screen_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.checkState = widget.target.value
      end

      # Default button.
      Button.new(@grid, t.resolution.default_button, :opts => LAYOUT_FILL_X).connect(SEL_COMMAND) do |sender, selector, event|
        @screen_width_field.text = DEFAULT_GAME_SCREEN_WIDTH.to_s
        calculate_screen_height
      end

      skip_grid

      nil
    end

    # Calculate the screen height based on the width, assuming 4:3 aspect ratio.
    protected
    def calculate_screen_height
      @screen_height_field.text = [(@screen_width_field.text.to_i * 3 / 4), 1].max.to_s

      nil
    end

    protected
    def add_hard_to_quit_mode(t, initial)
      @hard_to_quit_mode_target = FXDataTarget.new(initial)
      check = FXCheckButton.new(@grid, t.label, :width => 10,
                        :target => @hard_to_quit_mode_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.checkState = widget.target.value
      end

      skip_grid
      skip_grid
      skip_grid

      nil
    end

    protected
    def port_field(container, port)
      FXTextField.new(container, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER) do |widget|
        widget.text = port.to_s
        widget.connect(SEL_VERIFY, method(:verify_port))
      end
    end

    protected
    def address_field(container, address)
      FXTextField.new(container, 15, :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X) do |widget|
        widget.text = address
        widget.connect(SEL_VERIFY, method(:verify_address))
      end
    end

    protected
    def add_sid_directory(t, initial)
      FXLabel.new(@grid, t.label)
      @sid_directory_field = FXTextField.new(@grid, TEXT_COLUMNS) do |widget|
        widget.editable = false
        widget.text = initial
        widget.enabled = false
      end

      Button.new(@grid, t.browse_button, :opts => LAYOUT_FILL_X) do |button|
        button.connect(SEL_COMMAND) do |sender, selector, event|
          directory = FXFileDialog.getOpenDirectory(self, t.dialog.title, @sid_directory_field.text)
          unless directory.empty?
            directory = File.expand_path(directory)
            if SiD.valid_root?(directory)
              @sid_directory_field.text = directory
            else
              FXMessageBox.error(self, MBOX_OK, t.error.title, t.error.message(directory))
            end
          end
        end
      end

      skip_grid

      nil
    end

    protected
    def add_spectator_port(t, port)
      FXLabel.new(@grid, t.label)

      @spectate_port_field = port_field(@grid, port)

      Button.new(@grid, t.default_button, :opts => LAYOUT_FILL_X).connect(SEL_COMMAND) do |sender, selector, event|
        @spectate_port_field.text = DEFAULT_FLIPPED_PORT.to_s
      end

      skip_grid

      nil
    end
  end
end