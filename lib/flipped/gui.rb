begin
  # This way works fine on Windows.
  require 'fox16'
rescue Exception => ex  
  # Try it this way, for Ubuntu (and perhaps other Linuxi?).
  require 'rubygems'
  gem 'fxruby'
end

require 'yaml'
require 'fileutils'
require 'i18n'

require 'book'
require 'options_dialog'

module Flipped
  include Fox

  class Gui < FXMainWindow
    APPLICATION = "Flipped"
    WINDOW_TITLE = "#{APPLICATION} - The SiD flip-book tool"

    SETTINGS_FILE = File.join(INSTALLATION_ROOT, 'config', 'settings.yml')
    KEYS_FILE = File.join(INSTALLATION_ROOT, 'config', 'keys.yml')
    
    ICON_DIR = File.join(INSTALLATION_ROOT, 'media', 'icons')
    DEFAULT_TEMPLATE_DIR = File.join(INSTALLATION_ROOT, 'templates')

    IMAGE_WIDTH = 640
    IMAGE_HEIGHT = 416
    THUMB_SCALE = 0.25
    THUMB_WIDTH = IMAGE_WIDTH * THUMB_SCALE
    THUMB_HEIGHT = IMAGE_HEIGHT * THUMB_SCALE

    NAV_BUTTON_OPTIONS = { :opts => Fox::BUTTON_NORMAL|Fox::LAYOUT_CENTER_X|Fox::LAYOUT_FIX_WIDTH|Fox::LAYOUT_FIX_HEIGHT,
                           :width => 50, :height => 50 }

    MIN_INTERVAL = 1
    MAX_INTERVAL = 30
    NUM_INTERVALS_SEEN = 15

    SETTINGS_ATTRIBUTES = {
      :window_x => ['x', 100],
      :window_y => ['y', 100],
      :window_width => ['width', 800],
      :window_height => ['height', 800],

      :current_flip_book_directory => ['@current_flip_book_directory', Dir.pwd],
      :template_directory => ['@template_directory', DEFAULT_TEMPLATE_DIR],
      :slide_show_interval => ['slide_show_interval', 5],
      :slide_show_loops => ['slide_show_loops', false],

      :navigation_buttons_shown => ['@navigation_buttons_shown', true],
      :information_bar_shown => ['@information_bar_shown', true],
      :status_bar_shown => ['@status_bar_shown', true],
      :thumbnails_shown => ['@thumbnails_shown', true],
    }

    KEYS_ATTRIBUTES = {
      :open => ['@key[:open]', 'Ctrl-O'],
      :append => ['@key[:append]', 'Ctrl-A'],
      :save_as => ['@key[:save_as]', 'Ctrl-S'],
      :quit => ['@key[:quit]', 'Ctrl-Q'],

      :start => ['@key[:start]', 'Home'],
      :previous => ['@key[:previous]', 'Left'],
      :play => ['@key[:play]', 'Space'],
      :next => ['@key[:next]', 'Right'],
      :end => ['@key[:end]', 'End'],

      :toggle_nav_buttons_bar => ['@key[:toggle_nav_buttons_bar]', 'Ctrl-B'],
      :toggle_status_bar => ['@key[:toggle_status_bar]', 'Ctrl-U'],
      :toggle_thumbs => ['@key[:toggle_thumbs]', 'Ctrl-T'],
      :toggle_info => ['@key[:toggle_info]', 'Ctrl-I'],

      :loops => ['@key[:loops]', 'Ctrl-L'],
    }

    IMAGE_BACKGROUND_COLOR = Fox::FXRGB(0, 0, 0)

    HELP_TEXT = <<END_TEXT
#{APPLICATION} is a flip-book tool for SleepIsDeath (http://sleepisdeath.net).

Author: Spooner (Bil Bas)

Allows the user to view and edit flip-books.

Uses the FXRuby GUI library #{Fox::FXApp.copyright}
END_TEXT

    def initialize(app)
      super(app, WINDOW_TITLE, :opts => DECOR_ALL)

      I18n.load_path << Dir[File.join(INSTALLATION_ROOT, 'config', 'locales', '*.yml')]

      @key = {}
      read_config(KEYS_ATTRIBUTES, KEYS_FILE)
      
      FXToolTip.new(getApp(), TOOLTIP_NORMAL)
      @status_bar = FXStatusBar.new(self, :opts => LAYOUT_FILL_X|LAYOUT_SIDE_BOTTOM)
      
      create_menu_bar
      add_hot_keys

      @main_frame = FXVerticalFrame.new(self, LAYOUT_FILL_X|LAYOUT_FILL_Y)

      # Scrolling area into which to place thumbnail images.
      @thumbs_window = FXScrollWindow.new(@main_frame, LAYOUT_FIX_HEIGHT|LAYOUT_FILL_X, :height => THUMB_HEIGHT + 50)
      @thumbs_row = FXHorizontalFrame.new(@thumbs_window,
        :opts => LAYOUT_FIX_X|LAYOUT_FILL_Y,
        :padLeft => 0, :padRight => 0, :padTop => 0, :padBottom => 0,
        :width => THUMB_WIDTH)

      # Place to show current frame image full-size.      
      @image_viewer = FXImageView.new(@main_frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y)
      @image_viewer.backColor = IMAGE_BACKGROUND_COLOR
      @image_viewer.connect(SEL_RIGHTBUTTONRELEASE, method(:on_image_right_click))
      @image_viewer.connect(SEL_LEFTBUTTONRELEASE, method(:on_cmd_next))

      # Show info about the book and current frame.
      @info_bar = FXLabel.new(@main_frame, 'No flip-book loaded', nil, LAYOUT_FILL_X,
         :padLeft => 4, :padRight => 4, :padTop => 4, :padBottom => 4)

      add_button_bar(@main_frame)

      # Initialise various things.
      @book = Book.new # Currently loaded flipbook.
      @slide_show_timer = nil # Not initially playing.

      select_frame(-1)
      update_menus
    end

  protected
    attr_accessor :slide_show_interval
    def slide_show_interval #:nodoc
      @slide_show_interval_target.value
    end
    def slide_show_interval=(value) #:nodoc
      @slide_show_interval_target.value = value
    end

    def slide_show_loops? #:nodoc
      @slide_show_loops_target.value
    end
    alias_method :slide_show_loops, :slide_show_loops?
    attr_writer :slide_show_loops
    def slide_show_loops=(value) #:nodoc
      @slide_show_loops_target.value = value
    end

    def t(key, options = nil)
      str = I18n.t key, options
      raise Exception.new("Missing variable in '#{key}': '#{str}'") if str =~ /{{/
      str
    end

    def create_menu_bar
      menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X|FRAME_RAISED)

      # File menu
      file_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t('file'), nil, file_menu)

      create_menu(file_menu, :open)
      @append_menu = create_menu(file_menu, :append)
      FXMenuSeparator.new(file_menu)
      @save_menu = create_menu(file_menu, :save_as)
      FXMenuSeparator.new(file_menu)
      create_menu(file_menu, :quit)

      # Navigation menu.
      nav_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t('navigate'), nil, nav_menu)

      @start_menu = create_menu(nav_menu, :start)
      @previous_menu = create_menu(nav_menu, :previous)
      @play_menu = create_menu(nav_menu, :play)
      @next_menu = create_menu(nav_menu, :next)
      @end_menu = create_menu(nav_menu, :end)

      # Show menu.
      show_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t('show'), nil, show_menu)
      @toggle_navigation_menu = create_menu(show_menu, :toggle_nav_buttons_bar, FXMenuCheck)
      @toggle_info_menu = create_menu(show_menu, :toggle_info, FXMenuCheck)
      @toggle_status_menu = create_menu(show_menu, :toggle_status_bar, FXMenuCheck)
      @toggle_thumbs_menu = create_menu(show_menu, :toggle_thumbs, FXMenuCheck)

      # Options menu.
      options_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t('options'), nil, options_menu)
      
      @slide_show_loops_target = FXDataTarget.new
      @slide_show_loops_target.connect(SEL_COMMAND) do |sender, selector, event|
        select_frame(@current_frame_index) # Update buttons.
      end
      FXMenuCheck.new(options_menu, "#{t('loops.menu')}\t#{@key[:loops]}\t#{t('loops.help', :key => @key[:loops])}.",
                       :target => @slide_show_loops_target, :selector => FXDataTarget::ID_VALUE)

      @slide_show_interval_target = FXDataTarget.new
      # Ensure that playback changes to use the new interval.
      @slide_show_interval_target.connect(SEL_COMMAND) do |sender, selector, event|
        # Toggle the playing state, so we use the new interval immediately.
        if playing?
          play(false)
          play(true)
        end
      end

      interval_menu = FXMenuPane.new(menu_bar)
      (MIN_INTERVAL..MAX_INTERVAL).each do |i|
        FXMenuRadio.new(interval_menu, "#{i}", :target => @slide_show_interval_target, :selector => FXDataTarget::ID_OPTION + i)
      end
      FXMenuCascade.new(options_menu, "#{t('interval.menu')}\t\t#{t('interval.help')}", :popupMenu => interval_menu)
      
      FXMenuSeparator.new(options_menu)
      
      @options_menu = create_menu(options_menu, :settings)

      # Help menu
      help_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t('help'), nil, help_menu, LAYOUT_RIGHT)

      create_menu(help_menu, :about)
    end

    def on_cmd_about(sender, selector, event)
      dialog = FXMessageBox.new(self, "About #{APPLICATION}", HELP_TEXT, nil, MBOX_OK|DECOR_TITLE|DECOR_BORDER)
      dialog.execute

      return 1
    end

    def on_cmd_settings(sender, selector, event)
      dialog = OptionsDialog.new(self, :template_directory => @template_directory)

      if dialog.execute == 1
        @template_directory = dialog.template_directory
      end

      return 1
    end

    def create_menu(owner, name, type = FXMenuCommand, options = {})
      text = [t("#{name}.menu"), @key[name], t("#{name}.help", :key => @key[name])].join("\t")
      menu = type.new(owner, text, options)
      menu.connect(SEL_COMMAND, method(:"on_cmd_#{name}"))
      menu
    end

    # Convenience function to construct a PNG icon
    def load_icon(name)
      begin
        filename = File.join(ICON_DIR, "#{name}.png")
        icon = File.open(filename, 'rb') do |f|
          FXPNGIcon.new(getApp(), f.read)
        end
        icon.create
        icon
      rescue => ex
        raise RuntimeError, "Couldn't load icon: #{filename} (#{ex.message})"
      end
    end

    def on_cmd_toggle_thumbs(sender, selector, event)
      show_window(@thumbs_window, sender.checked?)
    end

    def on_cmd_toggle_status_bar(sender, selector, event)
      show_window(@status_bar, sender.checked?)
    end

    def on_cmd_toggle_nav_buttons_bar(sender, selector, event)
      show_window(@button_bar, sender.checked?)
    end

    def on_cmd_toggle_info(sender, selector, event)
      show_window(@info_bar, sender.checked?)
    end

    def show_window(window, show)
      if show
        window.show
      else
        window.hide
      end
      @main_frame.recalc
      return 1
    end

    def add_button_bar(window)
      @button_bar = FXHorizontalFrame.new(window, :opts => LAYOUT_CENTER_X)

      @start_button = create_button(@button_bar, :start)
      @previous_button = create_button(@button_bar, :previous)
      @play_button = create_button(@button_bar, :play)
      @next_button = create_button(@button_bar, :next)
      @end_button = create_button(@button_bar, :end)

      options_frame = FXVerticalFrame.new(@button_bar)

      FXCheckButton.new(options_frame, "#{t('loops.label')}\t#{t('loops.tip')}\t#{t('loops.help', :key => @key[:loops])}",
        :target => @slide_show_loops_target, :selector => FXDataTarget::ID_VALUE)

      interval_frame = FXHorizontalFrame.new(options_frame)
      FXLabel.new(interval_frame, "#{t('interval.label')}\t#{t('interval.tip')}\t#{t('interval.help', :key => @key[:interval])}")
      FXComboBox.new(interval_frame, 3, :target => @slide_show_interval_target, :selector => FXDataTarget::ID_VALUE) do |combo|
        (MIN_INTERVAL..MAX_INTERVAL).each {|i| combo.appendItem(i.to_s, i) }
        combo.editable = false
        combo.numVisible = NUM_INTERVALS_SEEN
      end

      nil
    end

    def create_button(menu, name)
      button = FXButton.new(menu, "\t#{t("#{name}.tip")}\t#{t("#{name}.help", :key => @key[name])}", load_icon(name), NAV_BUTTON_OPTIONS)
      button.connect(SEL_COMMAND, method(:"on_cmd_#{name}"))

      button
    end

    def update_menus
      if @book.size > 0
        @append_menu.enable
        @save_menu.enable
      else
        @append_menu.disable
        @save_menu.disable
      end

      nil
    end

    def show_frames(selected = 0)
      # Trim off excess thumb viewers.
      (@book.size...@thumbs_row.numChildren).reverse_each do |i|
        @thumbs_row.removeChild(@thumbs_row.childAtIndex(i))
      end

      # Create extra thumb viewers.
      (@thumbs_row.numChildren...@book.size).each do |i|
        FXVerticalFrame.new(@thumbs_row) do |packer|
          image_view = FXImageView.new(packer, :opts => LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT,
                                        :width => THUMB_HEIGHT, :height => THUMB_HEIGHT)

          image_view.connect(SEL_LEFTBUTTONRELEASE, method(:on_thumb_left_click))
          image_view.connect(SEL_RIGHTBUTTONRELEASE, method(:on_thumb_right_click))

          label = FXLabel.new(packer, "#{i + 1}", :opts => LAYOUT_FILL_X)
          packer.create
        end
        
        image = FXPNGImage.new(app, @book[i], IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP)
        image.create
        image.crop((image.width - image.height) / 2, 0, image.height, image.height)
        image.scale(THUMB_HEIGHT, THUMB_HEIGHT)

        @thumbs_row.childAtIndex(i).childAtIndex(0).image = image
      end

      update_menus

      select_frame(selected)

      nil
    end

    def on_cmd_start(sender, selector, event)
      select_frame(0)

      return 1
    end

    def on_cmd_previous(sender, selector, event)
      select_frame(@current_frame_index - 1) unless @current_frame_index == 0

      return 1
    end

    def on_cmd_play(sender, selector, event)
      play(!playing?)

      return 1
    end

    def on_slide_show_timer(sender, selector, event)
      if playing?
        select_frame((@current_frame_index + 1).modulo(@book.size))
        play((@current_frame_index < @book.size - 1) || slide_show_loops?)
      else
        play(false)
      end

      return 1
    end

    def playing?
      not @slide_show_timer.nil?
    end

    def play(value)
      if value
        @slide_show_timer = app.addTimeout(slide_show_interval * 1000, method(:on_slide_show_timer))
      else
        app.removeTimeout(@slide_show_timer) if @slide_show_timer
        @slide_show_timer = nil
      end

      name = (value ? :pause : :play)
      
      @play_menu.text = t("#{name}.menu")
      @play_menu.helpText = t("#{name}.help", :key => @key[name])

      @play_button.icon = load_icon(name)
      @play_button.tipText = t("#{name}.tip")
      @play_button.helpText = t("#{name}.help", :key => @key[name])

      nil
    end

    def on_cmd_next(sender, selector, event)
      select_frame(@current_frame_index + 1) unless @current_frame_index == @book.size - 1

      return 1
    end

    def on_cmd_end(sender, selector, event)
      select_frame(@book.size - 1)

      return 1
    end

    def select_frame(index)
      @current_frame_index = index
      img = FXPNGImage.new(app, @book[@current_frame_index], IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP)
      img.create
      @image_viewer.image = img

      @info_bar.text = if @book.size > 0
        "Frame #{index + 1} of #{@book.size}"
      else
        "Empty flip-book"
      end

      [@start_button, @start_menu, @previous_button, @previous_menu].each do |widget|
        if index > 0   
          widget.enable
        else
          widget.disable
        end
      end

      # Play is always enabled if we are in looping mode.
      if index < @book.size - 1 or (slide_show_loops? and @book.size > 0)
        @play_button.enable
        @play_menu.enable
      else
        @play_button.disable
        @play_menu.disable
      end

      [@end_button, @end_menu, @next_button, @next_menu].each do |widget|
        if index < @book.size - 1
          widget.enable
        else
          widget.disable
        end
      end

      nil
    end

    # Event when clicking on a thumbnail - select.
    def on_thumb_left_click(sender, selector, event)
      index = @thumbs_row.indexOfChild(sender.parent)
      select_frame(index)

      return 1
    end

    # Event when clicking on a thumbnail - context menu.
    def on_thumb_right_click(sender, selector, event)
      index = @thumbs_row.indexOfChild(sender.parent)
      image_context_menu(index, event.root_x, event.root_y)
      
      return 1
    end

    # Event when right-clicking on the main image - context menu.
    def on_image_right_click(sender, selector, event)
      if @book.size > 0
        image_context_menu(@current_frame_index, event.root_x, event.root_y)
        return 1
      else
        return 0
      end      
    end

    def image_context_menu(index, x, y)
      FXMenuPane.new(self) do |menu_pane|
        FXMenuCommand.new(menu_pane, "#{t('delete.menu')}\t\t#{t('delete.help', :index => index + 1)}").connect(SEL_COMMAND) do
          delete_frames(index)
        end

        FXMenuCommand.new(menu_pane, "#{t('delete_before.menu')}\t\t#{t('delete_before.help', :index => index + 1)}").connect(SEL_COMMAND) do
          delete_frames(*(0..index).to_a)
        end

        FXMenuCommand.new(menu_pane, "#{t('delete_after.menu')}\t\t#{t('delete_after.help', :index => index + 1, :to => @book.size - 1)}").connect(SEL_COMMAND) do
          delete_frames(*(index..(@book.size - 1)).to_a)
        end

        FXMenuCommand.new(menu_pane, "#{t('delete_identical.menu')}\t\t#{t('delete_identical.help', :index => index + 1)}").connect(SEL_COMMAND) do
          frame_data = @book[index]
          identical_frame_indices = []
          @book.frames.each_with_index do |frame, i|
            identical_frame_indices.push(i) if frame == frame_data
          end
          delete_frames(*identical_frame_indices)
        end

        menu_pane.create
        menu_pane.popup(nil, x, y)
        app.runModalWhileShown(menu_pane)
      end

      nil
    end

    def delete_frames(*indices)
      indices.sort.reverse_each {|index| @book.delete_at(index) }

      show_frames([indices.first, @book.size - 1].min)

      # Re-number everything after the first one deleted.
      (indices.min...@thumbs_row.numChildren).each do |i|
        @thumbs_row.childAtIndex(i).childAtIndex(1).text = "#{i + 1}"
      end

      nil
    end

    # Open a new flip-book
    def on_cmd_open(sender, selector, event)
      open_dir = FXFileDialog.getOpenDirectory(self, "Open flip-book directory", @current_flip_book_directory)
      return if open_dir.empty?
      
      begin
        app.beginWaitCursor do
          @book = Book.new(open_dir)
          @thumbs_row.children.each {|c| @thumbs_row.removeChild(c) }
          show_frames(0)
        end
        @current_flip_book_directory = open_dir
      rescue => ex
        log_error(ex)
        dialog = FXMessageBox.new(self, "Open error!",
                 "Failed to load flipbook from #{open_dir}, probably because it is not a flip-book directory.", nil,
                 MBOX_OK|DECOR_TITLE|DECOR_BORDER)
        dialog.execute
      end

      return 1
    end

    def log_error(exception)
      puts "#{exception.class}: #{exception}\n#{exception.backtrace.join("\n")}"
    end

    # Open a new flip-book
    def on_cmd_append(sender, selector, event)
      open_dir = FXFileDialog.getOpenDirectory(self, "Append flip-book directory", @current_flip_book_directory)
      return if open_dir.empty?

      begin
        app.beginWaitCursor do
          # Append new frames and select the first one.
          new_frame = @book.size
          @book.append(Book.new(open_dir))
          show_frames(new_frame)
        end
        @current_flip_book_directory = open_dir
      rescue => ex
        log_error(ex)
        dialog = FXMessageBox.new(self, "Open error!",
                 "Failed to load flipbook from #{open_dir}, probably because it is not a flip-book directory", nil,
                 MBOX_OK|DECOR_TITLE|DECOR_BORDER)
        dialog.execute
      end

      return 1
    end

    # Save this flip-book
    def on_cmd_save_as(sender, selector, event)
      save_dir = FXFileDialog.getSaveFilename(self, "Save flip-book directory", @current_flip_book_directory)
      return if save_dir.empty?

      if File.exists? save_dir
        dialog = FXMessageBox.new(self, "Save error!",
                 "File/folder #{save_dir} already exists, so flip-book cannot be saved.", nil,
                 MBOX_OK|DECOR_TITLE|DECOR_BORDER)
        dialog.execute
      else
        @current_flip_book_directory = save_dir
        begin
          @book.write(@current_flip_book_directory, @template_directory)
        rescue => ex
          log_error(ex)
          dialog = FXMessageBox.new(self, "Save error!",
                 "Failed to save flipbook to #{@current_flip_book_directory},\nbut failed because the template files found in #{@template_directory} were not valid.\nUse the menu Options->Settings to set a valid path to a flip-book templates directory.", nil,
                 MBOX_OK|DECOR_TITLE|DECOR_BORDER)
          dialog.execute
        end
      end

      return 1
    end

    # Quit the application
    def on_cmd_quit(sender, selector, event)
      @thumbnails_shown = @toggle_thumbs_menu.checkState == 1
      @status_bar_shown = @toggle_status_menu.checkState == 1
      @information_bar_shown = @toggle_info_menu.checkState == 1
      @navigation_buttons_shown = @toggle_navigation_menu.checkState == 1

      write_config(SETTINGS_ATTRIBUTES, SETTINGS_FILE)
      write_config(KEYS_ATTRIBUTES, KEYS_FILE)

      # Quit
      app.exit
      
      return 1
    end

    def read_config(attributes, filename)
      settings = if File.exists? filename
         File.open(filename) { |file| YAML::load(file) }
      else
        {}
      end

      attributes.each_pair do |key, data|
        name, default_value = data
        value = settings.has_key?(key) ? settings[key] : default_value
        if name[0] == '@'
          if name =~ /^(.*)\[(.*)\]$/ # @frog[:cheese]
            name, hash_key = $1, $2
            if hash_key[0] == ':'
              hash_key = hash_key[1..-1].to_sym
            end
            instance_variable_get(name)[hash_key] = value
          else  # @frog
            instance_variable_set(name, value)
          end
        else # frog (method) 
          send("#{name}=", value)
        end
      end

      nil
    end

    def write_config(attributes, filename)
      settings = {}
      attributes.each_pair do |key, data|
        name, default_value = data
        settings[key] = if name[0] == '@'
          if name =~ /^(.*)\[(.*)\]$/ # @frog[:cheese]
            name, hash_key = $1, $2
            if hash_key[0] == ':'
              hash_key = hash_key[1..-1].to_sym
            end

            instance_variable_get(name)[hash_key]
          else
            instance_variable_get(name) # @frog
          end
        else
          send(name) # frog (method)
        end
      end

      FileUtils::mkdir_p(File.dirname(filename))
      File.open(filename, 'w') { |file| file.puts(settings.to_yaml) }

      nil
    end

    def create
      read_config(SETTINGS_ATTRIBUTES, SETTINGS_FILE)

      @toggle_thumbs_menu.checkState = @thumbnails_shown
      show_window(@thumbs_window, @thumbnails_shown)

      @toggle_status_menu.checkState = @status_bar_shown
      show_window(@status_bar, @status_bar_shown)

      @toggle_info_menu.checkState = @information_bar_shown
      show_window(@info_bar, @information_bar_shown)

      @toggle_navigation_menu.checkState = @navigation_buttons_shown
      show_window(@button_bar, @navigation_buttons_shown)

      super
      show

      return 1
    end

    def add_hot_keys
      # Not a hotkey, but ensure that all attempts to quit are caught so
      # we can save settings.
      connect(SEL_CLOSE, method(:on_cmd_quit))
      
      accelTable.addAccel(fxparseAccel("Alt+F4"), self, FXSEL(SEL_CLOSE, 0))
    end
  end
end