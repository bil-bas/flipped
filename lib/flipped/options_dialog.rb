require 'book'
require 'dialog'
require 'sound'

module Flipped
  class OptionsDialog < Dialog
    public
    attr_reader :template_directory
    def template_directory
      @template_directory_field.text
    end

    public
    attr_reader :notification_sound
    def notification_sound
      @notification_sound_field.text
    end

    public
    def hard_to_quit_mode?
      @hard_to_quit_mode_target.value
    end

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

    protected
    def initialize(owner, translations, options = {})
      t = translations
      super(owner, t.title, t.accept_button, t.cancel_button)

      # Flip-book options
      add_template_directory(t.template_directory, options[:template_directory])
      add_notification_sound(t.notification_sound, options[:notification_sound])

      # Game options.
      add_user_name(t.user_name, options[:user_name])
      add_hard_to_quit_mode(t.hard_to_quit_mode, options[:hard_to_quit_mode])
      add_flip_book_pattern(t.flip_book_pattern, options[:flip_book_pattern])
      
      nil
    end

    protected
    def add_template_directory(t, initial_text)
      FXLabel.new(@grid, t.label).tipText = t.tip
      @template_directory_field = FXTextField.new(@grid, 40) do |text_field|
        text_field.editable = false
        text_field.text = initial_text
      end

      Button.new(@grid, t.browse_button) do |button|
        button.connect(SEL_COMMAND) do |sender, selector, event|
          directory = FXFileDialog.getOpenDirectory(self, t.dialog.title, @template_directory_field.text)
          unless directory.empty?
            if Book.valid_template_directory?(directory)
              @template_directory_field.text = directory
            else
              FXMessageBox.error(self, MBOX_OK, t.error.title,
                    t.error.message(directory))
            end
          end
        end
      end

      skip_grid

      nil
    end

    protected
    def add_notification_sound(t, initial_file_name)
      FXLabel.new(@grid, t.label).tipText = t.tip
      @notification_sound_field = FXTextField.new(@grid, 40) do |widget|
        widget.editable = false
        widget.text = initial_file_name
      end

      Button.new(@grid, t.browse_button) do |widget|
        widget.connect(SEL_COMMAND) do |sender, selector, event|
          filename = FXFileDialog.getOpenFilename(self, t.dialog.title, @notification_sound_field.text,
            t.dialog.pattern)
          unless filename.empty?
            @notification_sound_field.text = filename
          end
        end
      end

      Button.new(@grid, t.play_button) do |widget|
        widget.connect(SEL_COMMAND) do |sender, selector, event|
          Sound.play(@notification_sound_field.text)
        end
      end

      nil
    end

    protected
    def add_hard_to_quit_mode(t, initial)
      @hard_to_quit_mode_target = FXDataTarget.new(initial)
      check = FXCheckButton.new(@grid, t.label, :width => 10,
                        :target => @hard_to_quit_mode_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.checkState = widget.target.value
        widget.tipText = t.tip
      end

      skip_grid
      skip_grid
      skip_grid

      nil
    end

    protected
    def add_flip_book_pattern(t, pattern)
      FXLabel.new(@grid, t.label).tipText = t.tip

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
      FXLabel.new(@grid, t.label).tipText = t.tip

      @user_name_field = FXTextField.new(@grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|LAYOUT_FILL_X) do |widget|
        widget.text = initial
        widget.connect(SEL_VERIFY, method(:verify_name))
      end

      skip_grid
      skip_grid

      nil
    end
  end
end