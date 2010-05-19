# Require Gems
begin
  # This way works fine on Windows.
  require 'fox16'
  require 'fox16/colors'
  require 'r18n-desktop'
rescue Exception => ex
  # Try it this way, for Ubuntu, which doesn't set RUBYOPT properly (and perhaps other Linuxi?).
  require 'rubygems'
  gem 'fxruby'
  require 'fox16'
  require 'fox16/colors'
  gem 'r18n-desktop'
  require 'r18n-desktop'
end

# Standard libraries.
require 'yaml'
require 'fileutils'
require 'logger'

# Rest of the app.
require 'book'
require 'options_dialog'
require 'monitor_dialog'
require 'settings_manager'
require 'image_canvas'
require 'spectate_server'
require 'spectate_client'

module Flipped
  include Fox

  class Gui < FXMainWindow
    include SettingsManager

    R18n.set(R18n::I18n.new('en', File.join(INSTALLATION_ROOT, 'config', 'locales')))
    include R18n::Helpers

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

      :mouse_wheel_inverted => ['@mouse_wheel_inverted', false],

      :navigation_buttons_shown => ['@navigation_buttons_shown', true],
      :information_bar_shown => ['@information_bar_shown', true],
      :status_bar_shown => ['@status_bar_shown', true],
      :thumbnails_shown => ['@thumbnails_shown', true],

      :broadcast_when_monitoring => ['@broadcast_when_monitoring', false],
      :broadcast_port => ['@broadcast_port', SpectateServer::DEFAULT_PORT],

      :player_name => ['@player_name', 'Player']
    }

    KEYS_ATTRIBUTES = {
      :open => ['@key[:open]', 'Ctrl-O'],
      :append => ['@key[:append]', 'Ctrl-A'],
      :monitor => ['@key[:monitor]', 'Ctrl-M'],
      :spectate => ['@key[:spectate]', 'Ctrl-R'],
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

      :toggle_looping => ['@key[:loops]', 'Ctrl-L'],

      :delete_single => ['@key[:delete_single]', 'Ctrl-X'],
      :delete_before => ['@key[:delete_before]', ''],
      :delete_after => ['@key[:delete_after]', ''],
      :delete_identical => ['@key[:delete_identical]', 'Ctrl-Shift-X'],
    }

    FRAMES_RENDERED_PER_CHORE = 5
    SPECTATE_INTERVAL = 0.5 # Half a second between checking for receiving new frames.
    MONITOR_INTERVAL = 0.5 # Half a second between checking for new frames in folder.

    IMAGE_BACKGROUND_COLOR = Fox::FXColor::Black
    THUMB_BACKGROUND_COLOR = Fox::FXColor::White
    THUMB_SELECTED_COLOR = Fox::FXRGB(50, 50, 50)

    def initialize(app)
      @log = Logger.new(STDOUT)
      @log.progname = self.class.name

      super(app, '', :opts => DECOR_ALL)

      @key = {}
      read_config(KEYS_ATTRIBUTES, KEYS_FILE)
      
      FXToolTip.new(getApp(), TOOLTIP_NORMAL)
      @status_bar = FXStatusBar.new(self, :opts => LAYOUT_FILL_X|LAYOUT_SIDE_BOTTOM)
      
      create_menu_bar

      @main_frame = FXVerticalFrame.new(self, LAYOUT_FILL_X|LAYOUT_FILL_Y)

      # Scrolling area into which to place thumbnail images.
      @thumbs_window = FXScrollWindow.new(@main_frame, LAYOUT_FIX_HEIGHT|LAYOUT_FILL_X, :height => THUMB_HEIGHT + 50)
      @thumbs_row = FXHorizontalFrame.new(@thumbs_window,
        :opts => LAYOUT_FIX_X|LAYOUT_FILL_Y,
        :padLeft => 0, :padRight => 0, :padTop => 0, :padBottom => 0,
        :width => THUMB_WIDTH)
      @thumbs_row.backColor = THUMB_BACKGROUND_COLOR

      # Place to show current frame image full-size.      
      @image_viewer = ImageCanvas.new(@main_frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y)
      @image_viewer.backColor = IMAGE_BACKGROUND_COLOR
      @image_viewer.connect(SEL_RIGHTBUTTONRELEASE, method(:on_image_right_click))
      @image_viewer.connect(SEL_LEFTBUTTONRELEASE, method(:on_cmd_next))

      # Show info about the book and current frame.
      @info_bar = FXHorizontalFrame.new(@main_frame, :opts => LAYOUT_FILL_X, :padLeft => 4, :padRight => 4, :padTop => 4, :padBottom => 4)
      @frame_label = FXLabel.new(@info_bar, '', nil, :opts => LAYOUT_CENTER_X)
      @size_label = FXLabel.new(@info_bar, '', :opts => LAYOUT_RIGHT|LAYOUT_FIX_WIDTH|JUSTIFY_RIGHT, :width => 100)
      add_button_bar(@main_frame)

      # Initialise various things.
      @book = Book.new # Currently loaded flip-book.
      @slide_show_timer = nil # Not initially playing.
      @thumbs_to_add = [] # List of thumbs that need updating in a chore.

      select_frame(-1)

      add_hot_keys
    end

  protected

    attr_reader :log
    
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

    def create_menu_bar
      menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X|FRAME_RAISED)

      # File menu
      file_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.file, nil, file_menu)

      create_menu(file_menu, :open)
      @append_menu = create_menu(file_menu, :append)
      FXMenuSeparator.new(file_menu)
      @monitor_folder_menu = create_menu(file_menu, :monitor)
      @spectate_remote_menu = create_menu(file_menu, :spectate)
      FXMenuSeparator.new(file_menu)
      @save_menu = create_menu(file_menu, :save_as)
      FXMenuSeparator.new(file_menu)
      create_menu(file_menu, :quit)

      # Navigation menu.
      nav_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.navigate, nil, nav_menu)

      @start_menu = create_menu(nav_menu, :start)
      @previous_menu = create_menu(nav_menu, :previous)
      @play_menu = create_menu(nav_menu, :play)
      @next_menu = create_menu(nav_menu, :next)
      @end_menu = create_menu(nav_menu, :end)

      # edit menu
      edit_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.edit, nil, edit_menu)

      @delete_menu = create_menu(edit_menu, :delete_single)
      @delete_before_menu = create_menu(edit_menu, :delete_before)
      @delete_after_menu = create_menu(edit_menu, :delete_after)
      @delete_identical_menu = create_menu(edit_menu, :delete_identical)

      # Show menu.
      show_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.show, nil, show_menu)
      @toggle_navigation_menu = create_menu(show_menu, :toggle_nav_buttons_bar, FXMenuCheck)
      @toggle_info_menu = create_menu(show_menu, :toggle_info, FXMenuCheck)
      @toggle_status_menu = create_menu(show_menu, :toggle_status_bar, FXMenuCheck)
      @toggle_thumbs_menu = create_menu(show_menu, :toggle_thumbs, FXMenuCheck)

      # Options menu.
      options_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.options, nil, options_menu)
      
      @slide_show_loops_target = FXDataTarget.new
      @slide_show_loops_target.connect(SEL_COMMAND) do |sender, selector, event|
        select_frame(@current_frame_index) # Update buttons.
      end
      FXMenuCheck.new(options_menu, "#{t.loops.menu}\t#{@key[:loops]}\t#{t.loops.help(@key[:loops])}.",
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
      FXMenuCascade.new(options_menu, "#{t.interval.menu}\t\t#{t.interval.help}", :popupMenu => interval_menu)
      
      FXMenuSeparator.new(options_menu)
      
      @options_menu = create_menu(options_menu, :settings)

      # Help menu
      help_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.help, nil, help_menu, LAYOUT_RIGHT)

      create_menu(help_menu, :about)
    end

    def on_cmd_about(sender, selector, event)
      FXMessageBox.information(self, MBOX_OK, t.about.dialog.title, t.about.dialog.text)

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
      text = [t[name].menu, @key[name], t[name].help(@key[name])].join("\t")
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

      FXCheckButton.new(options_frame, "#{t.loops.label}\t#{t.loops.tip}\t#{t.loops.help(@key[:loops])}",
        :target => @slide_show_loops_target, :selector => FXDataTarget::ID_VALUE, :opts => JUSTIFY_NORMAL|ICON_AFTER_TEXT)

      interval_frame = FXHorizontalFrame.new(options_frame)
      FXLabel.new(interval_frame, "#{t.interval.label}\t#{t.interval.tip}\t#{t.interval.help(@key[:interval])}")
      FXComboBox.new(interval_frame, 3, :target => @slide_show_interval_target, :selector => FXDataTarget::ID_VALUE) do |combo|
        (MIN_INTERVAL..MAX_INTERVAL).each {|i| combo.appendItem(i.to_s, i) }
        combo.editable = false
        combo.numVisible = NUM_INTERVALS_SEEN
      end

      nil
    end

    def create_button(menu, name)
      button = FXButton.new(menu, "\t#{t[name].tip}\t#{t[name].help(@key[name])}", load_icon(name), NAV_BUTTON_OPTIONS)
      button.connect(SEL_COMMAND, method(:"on_cmd_#{name}"))

      button
    end

    def show_frames(selected = 0)
      # Trim off excess thumb viewers.
      (@book.size...@thumbs_row.numChildren).reverse_each do |i|
        @thumbs_row.removeChild(@thumbs_row.childAtIndex(i))
      end

      # Create extra thumb viewers.
      (@thumbs_row.numChildren...@book.size).each do |i|
        thumb_frame = FXVerticalFrame.new(@thumbs_row) do |packer|
          packer.backColor = FXColor::White
          image_view = FXImageView.new(packer, :opts => LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT,
                                        :width => THUMB_HEIGHT, :height => THUMB_HEIGHT)

          image_view.connect(SEL_LEFTBUTTONRELEASE, method(:on_thumb_left_click))
          image_view.connect(SEL_RIGHTBUTTONRELEASE, method(:on_thumb_right_click))

          label = FXLabel.new(packer, "#{i + 1}", :opts => LAYOUT_FILL_X)
          label.backColor = FXColor::White
          label.connect(SEL_LEFTBUTTONRELEASE, method(:on_thumb_left_click))
          label.connect(SEL_RIGHTBUTTONRELEASE, method(:on_thumb_right_click))
          packer.create
         end

        app.addChore(method :on_thumbs_chore) if @thumbs_to_add.empty?
        @thumbs_to_add.push thumb_frame
      end

      select_frame(selected)

      nil
    end

    def on_thumbs_chore(sender, selector, event)
      frames_to_render = FRAMES_RENDERED_PER_CHORE

      while (not @thumbs_to_add.empty?) and (frames_to_render > 0)
        thumb_frame = @thumbs_to_add.shift

        # Horrible fudge for this - I can't see an easy way to find out if the frame still exists!
        begin
          exists = thumb_frame.created?
        rescue Exception
          exists = false
        end

        if exists
          image_view = thumb_frame.childAtIndex(0)
          index = thumb_frame.childAtIndex(1).text.to_i - 1

          image = FXPNGImage.new(app, @book[index], IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP)
          image.create
          image.crop((image.width - image.height) / 2, 0, image.height, image.height)
          image.scale(THUMB_HEIGHT, THUMB_HEIGHT, 0) # Low quality, pixelised.

          image_view.image = image
          
          frames_to_render -= 1
        end
      end

      app.addChore(method :on_thumbs_chore) unless @thumbs_to_add.empty?
      
      return 1
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
      if playing? and not @book.empty?
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
      
      @play_menu.text = t[name].menu
      @play_menu.helpText = t[name].help(:key => @key[:play])

      @play_button.icon = load_icon(name)
      @play_button.tipText = t[name].tip
      @play_button.helpText = t[name].help(@key[:play])

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
      # Invert the old frame thumbnail.
      if defined?(@current_frame_index) and (@current_frame_index >= 0) and
              (@current_frame_index < @thumbs_row.numChildren)
        
        packer = @thumbs_row.childAtIndex(@current_frame_index)
        packer.backColor = THUMB_BACKGROUND_COLOR
        label = packer.childAtIndex(1)
        label.backColor, label.textColor = THUMB_BACKGROUND_COLOR, THUMB_SELECTED_COLOR
      end

      if index >= 0
        # Invert the new frame thumbnail.
        packer = @thumbs_row.childAtIndex(index)
        packer.backColor = THUMB_SELECTED_COLOR
        label = packer.childAtIndex(1)
        label.backColor, label.textColor = THUMB_SELECTED_COLOR, THUMB_BACKGROUND_COLOR

        # Show the image in the main area.
        @image_viewer.data = @book[index]
      end
      
      @current_frame_index = index

      if @book.empty?
        @frame_label.text = t.book.empty
        setTitle t.title.empty
        @size_label.text = ''
      else
        @frame_label.text = t.book.loaded(index + 1, @book.size)
        setTitle t.title.loaded(index + 1, @book.size)
        @size_label.text = "#{@image_viewer.image_width}x#{@image_viewer.image_height}"
      end

      [@start_button, @start_menu, @previous_button, @previous_menu].each do |widget|
        if index > 0   
          widget.enable
        else
          widget.disable
        end
      end

      # Play is always enabled if we are in looping mode.
      if (index < @book.size - 1) or (slide_show_loops? and not @book.empty?)
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

      [@append_menu, @save_menu, @delete_menu, @delete_after_menu, @delete_before_menu, @delete_identical_menu].each do |m|
        if can_delete? then m.disable else m.enable end
      end
      
      nil
    end

    def can_delete?
      not (@book.empty? or monitoring? or spectating?)
    end

    # Event when clicking on a thumbnail - select.
    def on_thumb_left_click(sender, selector, event)
      index = @thumbs_row.indexOfChild(sender.parent)
      select_frame(index)

      return 1
    end

    # Event when clicking on a thumbnail - context menu.
    def on_thumb_right_click(sender, selector, event)
      if can_delete?
        index = @thumbs_row.indexOfChild(sender.parent)
        select_frame(index)
        image_context_menu(index, event.root_x, event.root_y)
      end
      
      return 1
    end

    # Event when right-clicking on the main image - context menu.
    def on_image_right_click(sender, selector, event)
      if can_delete?
        image_context_menu(@current_frame_index, event.root_x, event.root_y)
      end

      return 1
    end

    def on_cmd_delete_single(sender, selector, event)
      delete_frames(@current_frame_index)
      return 1
    end

    def on_cmd_delete_before(sender, selector, event)
      delete_frames(*(0..@current_frame_index).to_a)
      return 1
    end

    def on_cmd_delete_after(sender, selector, event)
      delete_frames(*(@current_frame_index..(@book.size - 1)).to_a)
      return 1
    end

    def on_cmd_delete_identical(sender, selector, event)
      frame_data = @book[@current_frame_index]
      identical_frame_indices = []
      @book.frames.each_with_index do |frame, i|
        identical_frame_indices.push(i) if frame == frame_data
      end
      delete_frames(*identical_frame_indices)

      return 1
    end

    def image_context_menu(index, x, y)
      FXMenuPane.new(self) do |menu_pane|
        create_menu(menu_pane, :delete_single)
        create_menu(menu_pane, :delete_before)
        create_menu(menu_pane, :delete_after)
        create_menu(menu_pane, :delete_identical)

        menu_pane.create
        menu_pane.popup(nil, x, y)
        app.runModalWhileShown(menu_pane)
      end

      nil
    end

    def delete_frames(*indices)
      indices.sort.reverse_each do |index|
        @book.delete_at(index)
        @thumbs_row.removeChild(@thumbs_row.childAtIndex(index))
      end

      show_frames([indices.first, @book.size - 1].min)

      # Re-number everything after the first one deleted.
      (indices.min...@thumbs_row.numChildren).each do |i|
        @thumbs_row.childAtIndex(i).childAtIndex(1).text = "#{i + 1}"
      end

      # Clear the main image if all the frames are gone.
      if @book.empty?
        @image_viewer.data = nil
      end

      nil
    end

    # Open a new flip-book
    def on_cmd_open(sender, selector, event)
      open_dir = FXFileDialog.getOpenDirectory(self, t.open.dialog.title, @current_flip_book_directory)
      return if open_dir.empty?
      
      begin
        app.beginWaitCursor do
          @book = Book.new(open_dir)
          @thumbs_row.children.each {|c| @thumbs_row.removeChild(c) }
          show_frames(0)
        end
        @current_flip_book_directory = open_dir
        disable_monitors
      rescue => ex
        log.error { ex }
        error_dialog(t.open.error.title, t.open.error.text(open_dir))
      end

      return 1
    end

    # Open a new flip-book
    def on_cmd_append(sender, selector, event)
      open_dir = FXFileDialog.getOpenDirectory(self, t.append.dialog.title, @current_flip_book_directory)
      return if open_dir.empty?

      begin
        app.beginWaitCursor do
          # Append new frames and select the first one.
          new_frame = @book.size
          @book.append(Book.new(open_dir))
          show_frames(new_frame)
        end
        @current_flip_book_directory = open_dir
        disable_monitors
      rescue => ex
        log.error { ex }
        error_dialog(t.append.error.title, t.append.error.text(open_dir))
      end

      return 1
    end

    def error_dialog(caption, message)
      FXMessageBox.error(self, MBOX_OK, caption, message)
    end

    # Open a new flip-book and monitor it for changes.
    def on_cmd_monitor(sender, selector, event)
      dialog = MonitorDialog.new(self, t.monitor.dialog.title, :port => @broadcast_port, :player_name => @player_name,
        :flip_book_directory => @current_flip_book_directory, :broadcast => @broadcast_when_monitoring)

      return unless dialog.execute == 1

      directory = dialog.flip_book_directory
      broadcast = dialog.broadcast?
      port = dialog.port
      player_name = dialog.player_name
      begin
        app.beginWaitCursor do
          # Replace with new book, viewing last frame.
          @book = Book.new(directory)
          @thumbs_row.children.each {|c| @thumbs_row.removeChild(c) }
          show_frames(@book.size - 1)
        end
        @broadcast_when_monitoring = broadcast
        @current_flip_book_directory = directory
        @broadcast_port = port if broadcast # Only remember the port number of broadcasting.
        @player_name = player_name if broadcast

        disable_monitors
        self.monitoring = true

      rescue Exception => ex
        log.error { ex }
        error_dialog(t.monitor.error.load_failed.title, t.monitor.error.load_failed.text(directory))
      end

      begin
        self.broadcasting = true if @broadcast_when_monitoring
      rescue Exception => ex
        log.error { ex }
        error_dialog(t.monitor.error.server_failed.title, t.monitor.error.server_failed.text(port.to_s))
      end

      return 1
    end

    def disable_monitors
      spectating = false if spectating?
      monitoring = false if monitoring?
      broadcasting = false if broadcasting?
    end

    def monitoring?
      defined?(@monitor_timeout) ? (not @monitor_timeout.nil?) : false
    end

    def broadcasting?
      defined?(@spectate_server) ? (not @spectate_server.nil?) : false
    end
    
    def monitoring=(enable)
      if enable
        log.info { "Started monitoring"}
        @monitor_timeout = app.addTimeout(MONITOR_INTERVAL * 1000, method(:on_monitor_timeout), :repeat => true)
      else
        log.info { "Ended monitoring"}
        app.removeTimeout(@monitor_timeout)
        @monitor_timeout = nil
      end
    end

    def broadcasting=(enable)
      if enable
        log.info { "Started broadcasting"}
        @spectate_server = SpectateServer.new(@broadcast_port, @player_name)
      else
        log.info { "Ended broadcasting"}
        @spectate_server.close
        @spectate_server = nil
      end
    end

    def on_monitor_timeout(sender, selector, event)
      num_new_frames = @book.update(@current_flip_book_directory)

      if num_new_frames > 0
        @spectate_server.update_spectators(@book)
        show_frames(@book.size - 1)
      end

      if broadcasting?
        @spectate_server.update_spectators(@book) if @spectate_server.need_update?
      end

      return 1
    end

    # Open a new flip-book and monitor it for changes.
    def on_cmd_spectate(sender, selector, event)
      begin
        # TODO: Get address and port from a dialog.
        address = "127.0.0.1"
        port = SpectateServer::DEFAULT_PORT
        app.beginWaitCursor do
          # Replace with new book, viewing last frame.
          spectate_client = SpectateClient.new(address, :port => port)
          @book = Book.new
          @thumbs_row.children.each {|c| @thumbs_row.removeChild(c) }
          show_frames(-1)
          disable_monitors
          @spectate_client = spectate_client
          self.spectating = true
        end
      rescue => ex
        log.error { ex }
        error_dialog(t.spectate.error.title, t.spectate.error.text("#{address}:#{port}"))
      end

      return 1
    end

    def spectating?
      defined?(@spectate_client) ? (not @spectate_client.nil?) : false
    end

    def spectating=(enable)
      if enable
        log.info { "Started spectating"}
        @spectate_timeout = app.addTimeout(SPECTATE_INTERVAL * 1000, method(:on_spectate_timeout), :repeat => true)
      else
        log.info { "Ended spectating"}
        app.removeTimeout(@spectate_timeout)
        @spectate_timeout = nil
        @spectate_client.close
        @spectate_client = nil
      end
    end

    def on_spectate_timeout(sender, selector, event)
      new_frames = @spectate_client.frames_buffer

      unless new_frames.empty?
        @book.insert(@book.size, *new_frames)
        show_frames(@book.size - 1)
      end

      return 1
    end

    # Save this flip-book
    def on_cmd_save_as(sender, selector, event)
      save_dir = FXFileDialog.getSaveFilename(self, t.save_as.dialog.title, @current_flip_book_directory)
      return if save_dir.empty?

      if File.exists? save_dir
        error_dialog(t.save_as.error.exists.title,t.save_as.error.exists.text(save_dir))
      else
        @current_flip_book_directory = save_dir
        begin
          @book.write(save_dir, @template_directory)
        rescue => ex
          log.error { ex }
          error_dialog(t.save_as.error.templates.title,
                 t.save_as.error.templates.text(save_dir, @template_directory))
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

    def on_mouse_wheel(sender, selector, event)
      if event.code > 0 or (event.code < 0 and @mouse_wheel_inverted)
        on_cmd_previous(sender, selector, event)
      else
        on_cmd_next(sender, selector, event)
      end
    end

    def add_hot_keys
      # Not a hotkey, but ensure that all attempts to quit are caught so
      # we can save settings.
      connect(SEL_CLOSE, method(:on_cmd_quit))

      @image_viewer.connect(SEL_MOUSEWHEEL, method(:on_mouse_wheel))
      
      accelTable.addAccel(fxparseAccel("Alt+F4"), self, FXSEL(SEL_CLOSE, 0))
    end
  end
end