require 'fox16'
require 'fox16/colors'
require 'yaml'
require 'fileutils'

require 'book'
require 'options_dialog'

module Flipped
  include Fox

  class Gui < FXMainWindow
    APPLICATION = "Flipped"
    WINDOW_TITLE = "#{APPLICATION} - The SiD flip-book tool"

    SETTINGS_FILE = File.expand_path(File.join('..', 'config', 'settings.yml'))

    IMAGE_WIDTH = 640
    IMAGE_HEIGHT = 416
    THUMB_SCALE = 0.25
    THUMB_WIDTH = IMAGE_WIDTH * THUMB_SCALE
    THUMB_HEIGHT = IMAGE_HEIGHT * THUMB_SCALE

    NAV_BUTTON_OPTIONS = { :opts => Fox::BUTTON_NORMAL|Fox::LAYOUT_CENTER_X|Fox::LAYOUT_FIX_WIDTH|Fox::LAYOUT_FIX_HEIGHT,
                           :width => 90, :height => 50 }

    SETTINGS_ATTRIBUTES = {
      :window_x => [:x, 0],
      :window_y => [:y, 0],
      :window_width => [:width, 800],
      :window_height => [:height, 800],

      :current_flip_book_directory => [:@current_flip_book_directory, Dir.pwd],
      :template_directory => [:@template_directory, Dir.pwd],
      :slide_show_interval => [:@slide_show_interval, 5],
      :slide_show_loops => [:@slide_show_loops, false],

      :navigation_buttons_shown => [:@navigation_buttons_shown, true],
      :information_bar_shown => [:@information_bar_shown, true],
      :status_bar_shown => [:@status_bar_shown, true],
      :thumbnails_shown => [:@thumbnails_shown, true],
    }

    IMAGE_BACKGROUND_COLOR = Fox::FXColor::Black

    HELP_TEXT = <<END_TEXT
#{APPLICATION} is a flip-book tool for SleepIsDeath (http://sleepisdeath.net).

Author: Spooner (Bil Bas)

Allows the user to view and edit flip- books.
END_TEXT

    def initialize(app)
      super(app, WINDOW_TITLE, :opts => DECOR_ALL)

      FXToolTip.new(getApp(), TOOLTIP_NORMAL)
      @status_bar = FXStatusBar.new(self, :opts => LAYOUT_FILL_X|LAYOUT_SIDE_BOTTOM)
      
      create_menu
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
      @image_viewer.connect(SEL_RIGHTBUTTONPRESS, method(:on_cmd_previous))
      @image_viewer.connect(SEL_LEFTBUTTONPRESS, method(:on_cmd_next))

      # Show info about the book and current frame.
      @info_bar = FXLabel.new(@main_frame, 'No flip-book loaded', nil, LAYOUT_FILL_X,
         :padLeft => 4, :padRight => 4, :padTop => 4, :padBottom => 4)

      add_button_bar(@main_frame)

      # Initialise various things.
      @current_frame_index = 0
      @book = Book.new # Currently loaded flipbook.
      @playing = false # Is mode on?

      select_frame(0)
      update_menus
    end

    def create_menu
      menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X|FRAME_RAISED)

      # File menu
      file_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, "&File", nil, file_menu)

      @open_menu = FXMenuCommand.new(file_menu, "&Open flip-book...\tCtl-O\tOpen flip-book.")
      @open_menu.connect(SEL_COMMAND, method(:on_cmd_open))

      @append_menu = FXMenuCommand.new(file_menu, "A&ppend flip-book...\tCtl-P\tAppend flip-book to currently loaded flip-book.")
      @append_menu.connect(SEL_COMMAND, method(:on_cmd_append))
      
      FXMenuSeparator.new(file_menu)

      @save_menu = FXMenuCommand.new(file_menu, "&Save flip-book...\tCtl-S\tSave current flip-book.")
      @save_menu.connect(SEL_COMMAND, method(:on_cmd_save))

      FXMenuSeparator.new(file_menu)

      FXMenuCommand.new(file_menu, "&Quit\tCtl-Q").connect(SEL_COMMAND, method(:on_cmd_quit))

      # Navigation menu.
      nav_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, "&Navigate", nil, nav_menu)
      @start_menu = FXMenuCommand.new(nav_menu, "Skip to start\tHome\tSelect the first frame.")
      @start_menu.connect(SEL_COMMAND, method(:on_cmd_start))

      @previous_menu = FXMenuCommand.new(nav_menu, "Previous frame\tLeft\tSelect the previous frame.")
      @previous_menu.connect(SEL_COMMAND, method(:on_cmd_previous))

      @play_menu = FXMenuCommand.new(nav_menu, "Play/Pause\tSpace\tPlay or pause in slide-show mode.")
      @play_menu.connect(SEL_COMMAND, method(:on_cmd_play))

      @next_menu = FXMenuCommand.new(nav_menu, "Next frame\tRight\tSelect the next frame.")
      @next_menu.connect(SEL_COMMAND, method(:on_cmd_next))

      @end_menu = FXMenuCommand.new(nav_menu, "Skip to end\tEnd\tSelect the last frame.")
      @end_menu.connect(SEL_COMMAND, method(:on_cmd_end))

      # Show menu.
      show_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, "&Show", nil, show_menu)
      @toggle_navigation_menu = FXMenuCheck.new(show_menu, "&Buttons\tCtrl-B\tHide/show navigation buttons.")
      @toggle_navigation_menu.connect(SEL_COMMAND, method(:on_toggle_nav_buttons_bar))

      @toggle_info_menu = FXMenuCheck.new(show_menu, "&Information\tCtrl-I\tHide/show information about the book/frame.")
      @toggle_info_menu.connect(SEL_COMMAND, method(:on_toggle_info))

      @toggle_status_menu = FXMenuCheck.new(show_menu, "Status bar\t\tHide/show status bar.")
      @toggle_status_menu.connect(SEL_COMMAND, method(:on_toggle_status_bar))

      @toggle_thumbs_menu = FXMenuCheck.new(show_menu, "&Thumbnails\tCtl-T\tHide/show thumbnail strip.")
      @toggle_thumbs_menu.connect(SEL_COMMAND, method(:on_toggle_thumbs))

      # Options menu.
      options_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, "&Options", nil, options_menu)
      @options_menu = FXMenuCommand.new(options_menu, "Settings...\t\tView/set configuration.")
      @options_menu.connect(SEL_COMMAND) do |sender, selector, event|
        dialog = OptionsDialog.new(self)
        dialog.slide_show_interval = @slide_show_interval
        dialog.slide_show_loops = @slide_show_loops
        dialog.template_directory = @template_directory
        if dialog.execute == 1
          @slide_show_interval = dialog.slide_show_interval
          @slide_show_loops = dialog.slide_show_loops?
          @template_directory = dialog.template_directory
        end
        app.runModalWhileShown(dialog)
      end

      # Help menu
      help_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, "&Help", nil, help_menu, LAYOUT_RIGHT)

      FXMenuCommand.new(help_menu, "&About #{APPLICATION}...").connect(SEL_COMMAND) do
        help_dialog = FXMessageBox.new(self, "About #{APPLICATION}",
          HELP_TEXT, nil,
          MBOX_OK|DECOR_TITLE|DECOR_BORDER)
        help_dialog.execute
      end
    end

    def on_toggle_thumbs(sender, selector, event)
      show_window(@thumbs_window, sender.checked?)
    end

    def on_toggle_status_bar(sender, selector, event)
      show_window(@status_bar, sender.checked?)
    end

    def on_toggle_nav_buttons_bar(sender, selector, event)     
      show_window(@button_bar, sender.checked?)
    end

    def on_toggle_info(sender, selector, event)
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

      @start_button = FXButton.new(@button_bar, '<<<', NAV_BUTTON_OPTIONS)
      @start_button.connect(SEL_LEFTBUTTONPRESS, method(:on_cmd_start))
      @start_button.tipText = "Skip to first frame"

      @previous_button = FXButton.new(@button_bar, '<', NAV_BUTTON_OPTIONS)
      @previous_button.connect(SEL_LEFTBUTTONPRESS, method(:on_cmd_previous))
      @previous_button.tipText = "Previous frame"

      @play_button = FXButton.new(@button_bar, '|>', NAV_BUTTON_OPTIONS)
      @play_button.connect(SEL_LEFTBUTTONPRESS, method(:on_cmd_play))
      @play_button.tipText = "Play slide-show"

      @next_button = FXButton.new(@button_bar, '>', NAV_BUTTON_OPTIONS)
      @next_button.connect(SEL_LEFTBUTTONPRESS, method(:on_cmd_next))
      @next_button.tipText = "Next frame"

      @end_button = FXButton.new(@button_bar, '>>>', NAV_BUTTON_OPTIONS)
      @end_button.connect(SEL_LEFTBUTTONPRESS, method(:on_cmd_end))
      @end_button.tipText = "Skip to last frame"

      nil
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

    # Convenience function to construct a PNG icon.
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

          image_view.connect(SEL_LEFTBUTTONPRESS, method(:on_thumb_left_click))
          image_view.connect(SEL_RIGHTBUTTONPRESS, method(:on_thumb_right_click))

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
      select_frame([@current_frame_index - 1, 0].max)

      return 1
    end

    def on_cmd_play(sender, selector, event)
      @playing = !@playing

      @play_button.disable
      @play_button.enable

      if @playing
        @slide_show_timer = app.addTimeout(@slide_show_interval * 1000, method(:slide_show_timer))
        @play_button.text = '||'
        @play_button.tipText = "Pause slide-show"
      else
        app.removeTimeout(@slide_show_timer)
        @slide_show_timer = nil
        @play_button.text = '|>'      
        @play_button.tipText = "Play slide-show"
      end

      return 1
    end

    def slide_show_timer(sender, selector, event)
      if @playing
        select_frame((@current_frame_index + 1).modulo(@book.size))
        if @slide_show_loops or @current_frame_index < @book.size - 1
          @slide_show_timer = app.addTimeout(@slide_show_interval * 1000, method(:slide_show_timer))
        else
          @playing = false
          @play_button.text = '|>'
        end        
      end

      return 1
    end

    def on_cmd_next(sender, selector, event)
      select_frame([@current_frame_index + 1, @book.size - 1].min)

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

      # Avoid button-locking bug.
      [@start_button, @previous_button, @play_button, @next_button, @end_button].each do |widget|
        widget.disable
      end

      [@start_button, @start_menu, @previous_button, @previous_menu].each do |widget|
        if index > 0   
          widget.enable
        else
          widget.disable
        end
      end

      [@play_button, @play_menu, @end_button, @end_menu, @next_button, @next_menu].each do |widget|
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

    # Event when clicking on a thumbnail - delete.
    def on_thumb_right_click(sender, selector, event)
      index = @thumbs_row.indexOfChild(sender.parent)

      FXMenuPane.new(self) do |menu_pane|
        FXMenuCommand.new(menu_pane, "Delete frame\t\tDelete frame #{index + 1}." ).connect(SEL_COMMAND) do
          delete_frames(index)
        end

        FXMenuCommand.new(menu_pane, "Delete frame and all frames before it\t\tDelete frames 1 to #{index + 1}." ).connect(SEL_COMMAND) do
          delete_frames(*(0..index).to_a)
        end

        FXMenuCommand.new(menu_pane, "Delete frame and all frames after it\t\tDelete frames #{index + 1} to #{@book.size}." ).connect(SEL_COMMAND) do
          delete_frames(*(index..(@book.size - 1)).to_a)
        end

        FXMenuCommand.new(menu_pane, "Delete identical frames\t\tDelete all frames showing exactly the same image as this one." ).connect(SEL_COMMAND) do
          frame_data = @book[index]
          identical_frame_indices = []
          @book.frames.each_with_index do |frame, i|
            identical_frame_indices.push(i) if frame == frame_data
          end
          delete_frames(*identical_frame_indices)
        end

        menu_pane.create
        menu_pane.popup(nil, event.root_x, event.root_y)
        app.runModalWhileShown(menu_pane)
      end

      return 1
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
      begin
        app.beginWaitCursor do
          @book = Book.new(open_dir)
          show_frames
        end
        @current_flip_book_directory = open_dir
      rescue => ex
        puts ex.class, ex, ex.backtrace.join("\n")
        dialog = FXMessageBox.new(self, "Open error!",
                 "Failed to load flipbook from #{open_dir}, probably because it is not a flipbook directory.", nil,
                 MBOX_OK|DECOR_TITLE|DECOR_BORDER)
        dialog.execute
      end

      return 1
    end

    # Open a new flip-book
    def on_cmd_append(sender, selector, event)
      open_dir = FXFileDialog.getOpenDirectory(self, "Append flip-book directory", @current_flip_book_directory)
      begin
        app.beginWaitCursor do
          # Append new frames and select the first one.
          new_frame = @book.size
          @book.append(Book.new(open_dir))
          show_frames(new_frame)
        end
        @current_flip_book_directory = open_dir
      rescue => ex
        puts ex.class, ex, ex.backtrace.join("\n")
        dialog = FXMessageBox.new(self, "Open error!",
                 "Failed to load flipbook from #{open_dir}, probably because it is not a flipbook directory", nil,
                 MBOX_OK|DECOR_TITLE|DECOR_BORDER)
        dialog.execute
      end

      return 1
    end

    # Save this flip-book
    def on_cmd_save(sender, selector, event)
      save_dir = FXFileDialog.getSaveFilename(self, "Save flip-book directory", @current_flip_book_directory)
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

      write_config

      # Quit
      app.exit(0)
      
      return 1
    end

    def read_config
      settings = if File.exists? SETTINGS_FILE
         File.open(SETTINGS_FILE) { |file| YAML::load(file) }
      else
        {}
      end

      SETTINGS_ATTRIBUTES.each_pair do |key, data|
        name, default_value = data
        value = settings.has_key?(key) ? settings[key] : default_value
        if name.to_s[0] == '@'
          instance_variable_set(name, value)
        else
          send("#{name}=".to_sym, value)
        end
      end

      nil
    end

    def write_config
      settings = {}
      SETTINGS_ATTRIBUTES.each_pair do |key, data|
        name, default_value = data
        settings[key] = if name.to_s[0] == '@'
          instance_variable_get(name)
        else
          send(name)
        end
      end

      FileUtils::mkdir_p(File.dirname(SETTINGS_FILE))
      File.open(SETTINGS_FILE, 'w') { |file| file.puts(settings.to_yaml) }

      nil
    end

    def create
      read_config

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
      accelTable.addAccel(fxparseAccel("Alt+F4"), self, FXSEL(SEL_CLOSE, 0))
    end
  end
end