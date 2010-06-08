require 'log'

# Require Gems
require 'rubygems'
gem 'fxruby'
require 'fox16'
require 'fox16/colors'
include Fox

gem 'r18n-desktop'
require 'r18n-desktop'

# Standard libraries.
require 'yaml'
require 'fileutils'
require 'thread'

# Require GUI modules.
require 'defaults'
require 'gui_menus'
require 'gui_file_commands'

# Rest of the app.
require 'book'
require 'options_dialog'
require 'play_dialog'
require 'control_dialog'
require 'settings_manager'
require 'image_canvas'
require 'spectate_server'
require 'spectate_client'
require 'sound'
require 'sid'

module Flipped
  module ZoomOption
    HALF = 0
    ORIGINAL = 1
    DOUBLE = 2
    
    DEFAULT = ORIGINAL
  end

  SETTINGS_FILE = File.join(INSTALLATION_ROOT, 'config', 'settings.yml')
  KEYS_FILE = File.join(INSTALLATION_ROOT, 'config', 'keys.yml')

  version_file = File.join(File.dirname(__FILE__), 'version.yml')
  if File.exists? version_file
    version_data = YAML::load(File.read(version_file))
    VERSION = version_data[:version]
    BUILD_DATE = version_data[:build_date]
  else
    VERSION = 'TEST'
    BUILD_DATE = Time.at(0)
  end 

  class Gui < FXMainWindow
    include Log
    include SettingsManager

    log.info { "Version: #{VERSION}; Built: #{BUILD_DATE}" }

    R18n.set(R18n::I18n.new('en', File.join(EXECUTION_ROOT, 'config', 'locales')))
    include R18n::Helpers

    ICON_DIR = File.join(EXECUTION_ROOT, 'media', 'icons')

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

    FRAMES_RENDERED_PER_CHORE = 5
    SPECTATE_INTERVAL = 0.05 # Delay between checking for receiving new frames.
    MONITOR_INTERVAL = 0.2 # Delay between checking for new frames in folder.

    IMAGE_BACKGROUND_COLOR = Fox::FXColor::Black
    THUMB_BACKGROUND_COLOR = Fox::FXColor::White
    THUMB_SELECTED_COLOR = Fox::FXRGB(50, 50, 50)

    protected
    def initialize(app)
      super(app, '', :opts => DECOR_ALL)
      log.info { "Initializing GUI" }

      @key = {}
      read_config(KEYS_ATTRIBUTES, KEYS_FILE)

      FXToolTip.new(getApp(), TOOLTIP_NORMAL)
      @status_bar = FXStatusBar.new(self, :opts => LAYOUT_FILL_X|LAYOUT_SIDE_BOTTOM)

      create_menu_bar(MIN_INTERVAL..MAX_INTERVAL)
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
      @size_label = FXLabel.new(@info_bar, '', :opts => LAYOUT_RIGHT|LAYOUT_FIX_WIDTH|JUSTIFY_RIGHT, :width => 120)
      add_button_bar(@main_frame)

      # Initialise various things.
      @book = Book.new # Currently loaded flip-book.
      @slide_show_timer = nil # Not initially playing.
      @thumbs_to_add = [] # List of thumbs that need updating in a chore.

      # TODO: should be configured.
      @controller = true
      @turn_finishes_at = Time.now
      
      select_frame(-1)

      add_hot_keys
    end

    protected
    attr_accessor :slide_show_interval
    def slide_show_interval # :nodoc:
      @slide_show_interval_target.value
    end
    def slide_show_interval=(value) # :nodoc:
      @slide_show_interval_target.value = value
    end

    protected
    def slide_show_loops?
      @slide_show_loops_target.value
    end
    alias_method :slide_show_loops, :slide_show_loops?
    attr_writer :slide_show_loops
    def slide_show_loops=(value) # :nodoc:
      @slide_show_loops_target.value = value
    end

    protected
    def resize_frame(zoom)
      return if @book.empty?

      # Work out the new width.
      new_width = (width - @image_viewer.width) + (zoom * @image_viewer.image_height)
      new_height = (height - @image_viewer.height) + new_width - 8
      new_width = [new_width, 400].max if @button_bar.shown?
      resize(new_width, new_height)

      nil
    end

    protected
    def on_cmd_about(sender, selector, event)
      FXMessageBox.information(self, MBOX_OK, t.about.dialog.title, t.about.dialog.text(VERSION, BUILD_DATE.to_s))

      return 1
    end

    protected
    def on_cmd_settings(sender, selector, event)
      dialog = OptionsDialog.new(self, t.settings.dialog, :template_directory => @template_directory, :notification_sound => @notification_sound)

      if dialog.execute == 1
        @template_directory = dialog.template_directory
        @notification_sound = dialog.notification_sound
      end

      return 1
    end

    # Convenience function to construct a PNG icon
    protected
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

    protected
    def on_cmd_toggle_thumbs(sender, selector, event)
      show_window(@thumbs_window, sender.checked?)
    end

    protected
    def on_cmd_toggle_status_bar(sender, selector, event)
      show_window(@status_bar, sender.checked?)
    end

    protected
    def on_cmd_toggle_nav_buttons_bar(sender, selector, event)
      show_window(@button_bar, sender.checked?)
    end

    protected
    def on_cmd_toggle_info(sender, selector, event)
      show_window(@info_bar, sender.checked?)
    end

    protected
    def show_window(window, show)
      if show
        window.show
      else
        window.hide
      end
      @main_frame.recalc
      return 1
    end

    protected
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

    protected
    def create_button(menu, name)
      button = FXButton.new(menu, "\t#{t[name].tip}\t#{t[name].help(@key[name])}", load_icon(name), NAV_BUTTON_OPTIONS)
      button.connect(SEL_COMMAND, method(:"on_cmd_#{name}"))

      button
    end

    protected
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

      @zoom_target.value = ZoomOption::DEFAULT
      resize_frame(1)

      nil
    end

    protected
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

    protected
    def on_cmd_start(sender, selector, event)
      select_frame(0)

      return 1
    end

    protected
    def on_cmd_previous(sender, selector, event)
      select_frame(@current_frame_index - 1) unless @current_frame_index == 0

      return 1
    end

    protected
    def on_cmd_play(sender, selector, event)
      play(!playing?)

      return 1
    end

    protected
    def on_slide_show_timer(sender, selector, event)
      if playing? and not @book.empty?
        select_frame((@current_frame_index + 1).modulo(@book.size))
        play((@current_frame_index < @book.size - 1) || slide_show_loops?)
      else
        play(false)
      end

      return 1
    end

    protected
    def playing?
      not @slide_show_timer.nil?
    end

    protected
    def play(value)
      if value
        @slide_show_timer = app.addTimeout(slide_show_interval * 1000, method(:on_slide_show_timer))
      else
        app.removeTimeout(@slide_show_timer) if @slide_show_timer
        @slide_show_timer = nil
      end

      name = (value ? :pause : :play)
      
      @play_menu.text = t[name].menu
      @play_menu.helpText = t[name].help(:key => @key[name])

      @play_button.icon = load_icon(name)
      @play_button.tipText = t[name].tip
      @play_button.helpText = t[name].help(@key[name])

      nil
    end

    protected
    def on_cmd_next(sender, selector, event)
      select_frame(@current_frame_index + 1) unless @current_frame_index == @book.size - 1

      return 1
    end

    protected
    def on_cmd_end(sender, selector, event)
      select_frame(@book.size - 1)

      return 1
    end

    protected
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

        @image_viewer.on_update do |original_width, original_height, shown_width|
          @size_label.text = "#{original_width}x#{original_height} @ #{(shown_width * 100.0 / original_height).round}%"
        end

        # Show the image in the main area.
        @image_viewer.data = @book[index]
      end
      
      @current_frame_index = index

      if @book.empty?
        @size_label.text = ''
      end

      update_info_and_title

      [@start_button, @start_menu, @previous_button, @previous_menu].each do |widget|
        widget.enabled = (index > 0)
      end

      # Play is always enabled if we are in looping mode.
      [@play_button, @play_menu].each do |widget|
        widget.enabled = (index < @book.size - 1) or (slide_show_loops? and not @book.empty?)
      end

      [@end_button, @end_menu, @next_button, @next_menu].each do |widget|
        widget.enabled = (index < @book.size - 1)
      end

      @zoom_menu.enabled = (not @book.empty?)

      [@append_menu, @delete_menu, @delete_after_menu, @delete_before_menu, @delete_identical_menu].each do |m|
        m.enabled = can_delete?
      end

      @save_menu.enabled = (not @book.empty?)
      
      nil
    end

    protected
    def current_player_name
      if controller_turn?
        @spectate_client.controller_name
      else
        @spectate_client.player_name
      end
    end

    protected
    def current_player_time_limit
      if controller_turn?
        @spectate_client.controller_time_limit
      else
        @spectate_client.player_time_limit
      end
    end

    # Update the info line and the title bar.
    protected
    def update_info_and_title
      if spectating?
        if @spectate_client.story_started_at
          # Clocks might be unsynced, so assume that the game was always started BEFORE now.
          elapsed = Time.at([Time.now - @spectate_client.story_started_at, 0].max)
          elapsed = "%d:%02d:%02d" % [elapsed.hour, elapsed.min, elapsed.sec]
          time_left = (@turn_finishes_at - Time.now).ceil
          type = controller_turn? ? t.controller : t.player
          setTitle t.title.spectate(@current_frame_index + 1, @book.size, elapsed, type, time_left, current_player_name)
          @frame_label.text = t.book.spectate(@current_frame_index + 1, @book.size, elapsed, type, time_left, current_player_name)
        else
          setTitle t.title.waiting_for_start(@spectate_client.story_name)
          @frame_label.text = t.book.waiting_for_start(@spectate_client.story_name)
        end
      else
        if @book.empty?
          setTitle t.title.empty
          @frame_label.text = t.book.empty
        else
          setTitle t.title.loaded(@current_frame_index + 1, @book.size)
          @frame_label.text = t.book.loaded(@current_frame_index + 1, @book.size)          
        end
      end
    end

    protected
    def can_delete?
      not (@book.empty? or monitoring? or spectating?)
    end

    # Event when clicking on a thumbnail - select.
    protected
    def on_thumb_left_click(sender, selector, event)
      index = @thumbs_row.indexOfChild(sender.parent)
      select_frame(index)

      return 1
    end

    # Event when clicking on a thumbnail - context menu.
    protected
    def on_thumb_right_click(sender, selector, event)
      if can_delete?
        index = @thumbs_row.indexOfChild(sender.parent)
        select_frame(index)
        image_context_menu(index, event.root_x, event.root_y)
      end
      
      return 1
    end

    # Event when right-clicking on the main image - context menu.
    protected
    def on_image_right_click(sender, selector, event)
      if can_delete?
        image_context_menu(@current_frame_index, event.root_x, event.root_y)
      end

      return 1
    end

    protected
    def on_cmd_delete_single(sender, selector, event)
      delete_frames(@current_frame_index)
      return 1
    end

    protected
    def on_cmd_delete_before(sender, selector, event)
      delete_frames(*(0..@current_frame_index).to_a)
      return 1
    end

    protected
    def on_cmd_delete_after(sender, selector, event)
      delete_frames(*(@current_frame_index..(@book.size - 1)).to_a)
      return 1
    end

    protected
    def on_cmd_delete_identical(sender, selector, event)
      frame_data = @book[@current_frame_index]
      identical_frame_indices = []
      @book.frames.each_with_index do |frame, i|
        identical_frame_indices.push(i) if frame == frame_data
      end
      delete_frames(*identical_frame_indices)

      return 1
    end

    protected
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

    protected
    def error_dialog(caption, message)
      FXMessageBox.error(self, MBOX_OK, caption, message)
    end

    # Open a new flip-book and monitor it for changes.
    protected
    def on_cmd_play_sid(sender, selector, event)
      dialog = PlayDialog.new(self, t, :spectate_port => @spectate_port, :user_name => @user_name,
        :time_limit => @player_time_limit, :screen_width => @player_screen_width, :screen_height => @player_screen_height,
        :full_screen => @player_full_screen, :hard_to_quit_mode => @hard_to_quit_mode,
        :controller_address => @controller_address,
        :sid_directory => @player_sid_directory,
        :flip_book_pattern => @flip_book_pattern)

      return unless dialog.execute == 1

      begin
        app.beginWaitCursor do
          @book = Book.new
          @thumbs_row.children.each {|c| @thumbs_row.removeChild(c) }
          show_frames(@book.size - 1)
        end
        @spectate_port = dialog.spectate_port
        @user_name = dialog.user_name
        @player_time_limit = dialog.time_limit
        @player_screen_width = dialog.screen_width
        @player_screen_height = dialog.screen_height
        @player_full_screen = dialog.full_screen?
        @hard_to_quit_mode = dialog.hard_to_quit_mode?
        @controller_address = dialog.controller_address
        @player_sid_directory = dialog.sid_directory
        @flip_book_pattern = dialog.flip_book_pattern

        @story_ended_at = nil

        disable_monitors
        select_frame(@book.size - 1)
        self.monitoring = true

      rescue Exception => ex
        log.error { ex }
        error_dialog(t.play_sid.error.load_failed.title, t.play_sid.error.load_failed.text(@sid_directory))
      end

      begin
        # Connect to the controller, in order to spectate own story.
        @spectate_client = SpectateClient.new(@controller_address, @spectate_port, @user_name, :player, @player_time_limit)
        @spectate_client.on_sid_started(method(:on_sid_started))
        self.spectating = true
      rescue Exception => ex
        log.error { ex }
        error_dialog(t.play_sid.error.server_failed.title, t.play_sid.error.server_failed.text(@spectate_port.to_s))
      end

      return 1
    end

    # SiD has been started by the controller and the player is being informed of the port.
    protected
    def on_sid_started(port)
      log.info { "SiD started remotely on port #{port}. Going to connect..."}
      @sid = SiD.new(@player_sid_directory)
      @sid.port = port
      @sid.default_server_address = @controller_address
      @sid.time_limit = @player_time_limit
      @sid.screen_width = @player_screen_width
      @sid.screen_height = @player_screen_height
      @sid.fullscreen = @player_full_screen

      # Find out what the path to the flip-book directory the game will create will be called.
      @story_flip_book_directory = @sid.flip_book_directory(@sid.number_of_automatic_flip_books + 1)

      Thread.new do
        @sid.run(:player) do |sid|
          sleep 0.5 # Allow the game to finish writing the files.
          if File.directory? @story_flip_book_directory
            rename_flip_book(@story_flip_book_directory, @spectate_client, @flip_book_pattern)
            @story_ended_at = Time.now
          end
          disable_monitors
        end
      end

      nil
    end

    protected
    def expand_flip_book_pattern(spectate_client, pattern)
      ("FLIPPED " + pattern).gsub(FlipBookPattern::PATTERN) do |code|
         case code
          when FlipBookPattern::CONTROLLER
            spectate_client.controller_name
          when FlipBookPattern::PLAYER
            spectate_client.player_name
          when FlipBookPattern::STORY
            spectate_client.story_name
          when FlipBookPattern::DATE
            spectate_client.story_started_at.strftime("%Y-%m-%d")
          when FlipBookPattern::TIME
            # For filename, so can't use colon, ':'.
            spectate_client.story_started_at.strftime("%H.%M")
          else
            code
        end
      end
    end

    protected
    def rename_flip_book(directory, spectate_client, pattern)

      new_directory = @sid.ensure_unique_flip_book(expand_flip_book_pattern(spectate_client, pattern))
      FileUtils.mv(directory, new_directory)

      new_directory
    end

    protected
    def disable_monitors
      self.spectating = false if spectating?
      self.monitoring = false if monitoring?
      update_info_and_title
    end

    protected
    def monitoring?
      defined?(@monitor_timeout) ? (not @monitor_timeout.nil?) : false
    end

    protected
    attr_writer :monitoring
    def monitoring=(enable) # :nodoc:
      if enable
        log.info { "Started monitoring"}
        @monitor_timeout = app.addTimeout(MONITOR_INTERVAL * 1000, method(:on_monitor_timeout), :repeat => true)
      else
        log.info { "Ended monitoring"}
        app.removeTimeout(@monitor_timeout)
        @monitor_timeout = nil
      end
    end

    protected
    def on_monitor_timeout(sender, selector, event)
      unless spectating? and @spectate_client.story_started_at
        if @story_flip_book_directory and Book.valid_flip_book_directory?(@story_flip_book_directory)
            @current_flip_book_directory = @story_flip_book_directory
            @spectate_client.send_story_started
            log.info { "Story started with flip-book at '#{@story_flip_book_directory}'" }
        else
          update_info_and_title
          return 1
        end
      end

      num_new_frames = @book.update(@current_flip_book_directory)

      if num_new_frames > 0
        # Send all the new frames to the server.
        @spectate_client.send_frames(@book.frames[(-num_new_frames)..-1])

        # Always select the last frame.
        show_frames(@book.size - 1)

        # Player gets notified on their own turn
        if notification_enabled? and player_turn?
          Sound.play(@notification_sound)
        end

        @turn_finishes_at = Time.now + current_player_time_limit
      end

      update_info_and_title

      return 1
    end

    # Open a new flip-book and monitor it for changes.
    protected
    def on_cmd_control_sid(sender, selector, event)
      dialog = ControlDialog.new(self, t, :spectate_port => @spectate_port,
        :user_name => @user_name, :flip_book_directory => @current_flip_book_directory,
        :time_limit => @controller_time_limit, :story_name => @story_name,
        :screen_width => @controller_screen_width, :screen_height => @controller_screen_height,
        :full_screen => @controller_full_screen, :hard_to_quit_mode => @hard_to_quit_mode,
        :sid_directory => @controller_sid_directory, :sid_port => @sid_port,
        :flip_book_pattern => @flip_book_pattern)

      return unless dialog.execute == 1
      
      begin
        app.beginWaitCursor do
          # Replace with new book, viewing last frame.
          @spectate_server = SpectateServer.new(dialog.spectate_port)         
          @book = Book.new
          @thumbs_row.children.each {|c| @thumbs_row.removeChild(c) }
          show_frames(-1)
          disable_monitors

          @spectate_client = SpectateClient.new('localhost', dialog.spectate_port, dialog.user_name, :controller, dialog.time_limit)
          @spectate_client.on_story_started do |name, time|
            request_event(:on_story_started, name, time)
          end
          @spectate_client.on_frame_received do |frame_data|
            request_event(:on_frame_received, frame_data)
          end
          @spectate_client.story_name = dialog.story_name
          @spectate_port = dialog.spectate_port
          @user_name = dialog.user_name
          @flip_book_pattern = dialog.flip_book_pattern

          @controller_time_limit = dialog.time_limit
          @controller_screen_width = dialog.screen_width
          @controller_screen_height = dialog.screen_height
          @controller_full_screen = dialog.full_screen?
          @controller_sid_directory = dialog.sid_directory
          @sid_port = dialog.sid_port
          @story_name = dialog.story_name
          @hard_to_quit_mode = dialog.hard_to_quit_mode?

          @sid = SiD.new(@controller_sid_directory)
          @sid.port = @sid_port
          @sid.time_limit = @controller_time_limit
          @sid.screen_width = @controller_screen_width
          @sid.screen_height = @controller_screen_height
          @sid.fullscreen = @controller_full_screen
          @spectate_client.send(Message::SiDStarted.new(:port => @sid_port))
          @sid.run(:controller) do |sid|
            sleep 0.5
            unless @book.empty?
              flip_book_dir = @sid.ensure_unique_flip_book(expand_flip_book_pattern(@spectate_client, @flip_book_pattern))
              log.info { "Writing #{@book.size} frames to #{flip_book_dir}" }
              @book.write(flip_book_dir, @template_directory)
            end
            disable_monitors
          end

          self.spectating = true
          select_frame(@book.size - 1)
        end
      rescue => ex
        log.error { ex }
        error_dialog(t.control_sid.error.title, t.control_sid.error.text("#{@spectate_port}"))
      end

      return 1
    end

    protected
    def on_cmd_spectate_sid(sender, selector, event)
      return # TODO: Complete implementation of this.

      dialog = SpectateDialog.new(self, t, :spectate_address => @controller_address, :spectate_port => @spectate_port,
        :user_name => @user_name, :flip_book_pattern => @flip_book_pattern)

      return unless dialog.execute == 1

      begin
        app.beginWaitCursor do
          @spectate_client = SpectateClient.new(dialog.spectate_address, dialog.spectate_port, dialog.user_name, :spectator, nil)
          @spectate_client.on_story_started do |name, time|
            request_event(:on_story_started, name, time)
          end
          @spectate_client.on_frame_received do |frame_data|
            request_event(:on_frame_received, frame_data)
          end
          # Replace with new book, viewing last frame.
          @book = Book.new
          @thumbs_row.children.each {|c| @thumbs_row.removeChild(c) }
          show_frames(-1)
          disable_monitors          
          @spectate_client.story_name = dialog.story_name
          @controller_address = dialog.spectate_address
          @spectate_port = dialog.spectate_port
          @user_name = dialog.user_name
          @flip_book_pattern = dialog.flip_book_pattern

          # TODO: How to manage this?
#          @sid = SiD.new(@controller_sid_directory)
#          unless @book.empty?
#            flip_book_dir = @sid.ensure_unique_flip_book(expand_flip_book_pattern(@spectate_client, @flip_book_pattern))
#            log.info { "Writing #{@book.frames} frames to #{flip_book_dir}" }
#            @book.write(flip_book_dir, @template_directory)
#          end
#          disable_monitors

          self.spectating = true
          select_frame(@book.size - 1)
        end
      rescue => ex
        log.error { ex }
        error_dialog(t.spectate_sid.error.title, t.spectate_sid.error.text(@controller_address, @spectate_port))
      end

      return 1
    end

    protected
    def spectating?
      defined?(@spectate_client) ? (not @spectate_client.nil?) : false
    end

    protected
    attr_writer :spectating
    def spectating=(enable) # :nodoc:
      if enable
        log.info { "Started spectating"}
        unless monitoring?
          @spectate_timeout = app.addTimeout(SPECTATE_INTERVAL * 1000, method(:on_spectate_timeout), :repeat => true)
        end
      else
        log.info { "Ended spectating"}
        if @spectate_timeout
          app.removeTimeout(@spectate_timeout)
          @spectate_timeout = nil
        end
        
        @spectate_client.close if @spectate_client
        @spectate_client = nil

        @spectate_server.close if @spectate_server
        @spectate_server = nil
      end
    end

    protected
    def on_spectate_timeout(sender, selector, event)
      update_info_and_title
      
      nil
    end

    protected
    def on_story_started(name, started_at)
      @story_flip_book_directory = expand_flip_book_pattern(@spectate_client, @flip_book_pattern)
      log.info { "Story '#{name}' started at #{started_at} with flip-book at #{@story_flip_book_directory}" }
      nil
    end

    protected
    def on_sid_started_controller(name, started_at)
       @current_flip_book_directory = @story_flip_book_directory
       @spectate_client.send_story_started
       log.info { "Story started with flip-book at '#{@story_flip_book_directory}'" }
    end

    # Received new frames.
    # Returns: nil
    protected
    def on_frame_received(frame_data)
      @book.insert(@book.size, frame_data)
      show_frames(@book.size - 1)

      # Spectators get all notifications. Controller only gets it on start of their turn.
      if notification_enabled? and (controller_turn? or (not controller?))
        Sound.play(@notification_sound)
      end

      # TODO: Should be the time that the last frame was created, not when it was received.
      @turn_finishes_at = Time.now + current_player_time_limit

      update_info_and_title

      nil
    end

    protected
    def player?
      monitoring?
    end

    protected
    def controller?
      @controller
    end

    protected
    def controller_turn?
      @book.size.modulo(2) == 0
    end

    protected
    def player_turn?
      @book.size.modulo(2) == 1
    end

    protected
    def notification_enabled?
      @notification_enabled
    end

    protected
    def create
      log.info { "Creating GUI" }

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

    protected
    def on_mouse_wheel(sender, selector, event)
      if event.code > 0 or (event.code < 0 and @mouse_wheel_inverted)
        on_cmd_previous(sender, selector, event)
      else
        on_cmd_next(sender, selector, event)
      end
    end

    protected
    def add_hot_keys
      # Not a hotkey, but ensure that all attempts to quit are caught so
      # we can save settings.
      connect(SEL_CLOSE, method(:on_cmd_quit))

      @image_viewer.connect(SEL_MOUSEWHEEL, method(:on_mouse_wheel))
      
      accelTable.addAccel(fxparseAccel("Alt+F4"), self, FXSEL(SEL_CLOSE, 0))
    end

    # Request that a method be called when the GUI is free. Interrupts will be called in the order that they were
    # requested in.
    #
    # === Parameters
    # +method+:: Name of method to call [Symbol]
    # +args+:: Arguments to pass to the method [Array]
    #
    # Returns: nil
    protected
    def request_event(method_name, *args)
      unless defined? @pending_events
        @pending_events = Array.new
        @pending_events.extend Mutex_m
      end

      @pending_events.synchronize do
        if @pending_events.empty?
          app.addChore(method :on_requested_events_chore)
        end

        @pending_events.push [method(method_name), args]
      end

      nil
    end

    # Call the events that have previously been requested via #request_event.
    #
    # Returns: nil
    protected
    def on_requested_events_chore(sender, selector, event)
      @pending_events.synchronize do
        @pending_events.each do |method, args|
          method.call(*args)
        end

        @pending_events.clear
      end

      nil
    end
  end
end