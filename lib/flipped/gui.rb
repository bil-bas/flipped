require 'fox16'
require 'fox16/colors' 

require 'book'
require 'options_dialog'

module Flipped
  include Fox

  class Gui < FXMainWindow
    APPLICATION = "Flipped"
    WINDOW_TITLE = "#{APPLICATION} - The SiD flip-book tool"

    IMAGE_WIDTH = 640
    IMAGE_HEIGHT = 416
    THUMB_SCALE = 0.25
    THUMB_WIDTH = IMAGE_WIDTH * THUMB_SCALE
    THUMB_HEIGHT = IMAGE_HEIGHT * THUMB_SCALE
    DEFAULT_SLIDE_SHOW_INTERVAL = 5

    NAV_BUTTON_OPTIONS = { :opts => Fox::BUTTON_NORMAL|Fox::LAYOUT_CENTER_X|Fox::LAYOUT_FIX_WIDTH|Fox::LAYOUT_FIX_HEIGHT,
                           :width => 90, :height => 50 }

    DEFAULT_WINDOW_WIDTH = 800
    DEFAULT_WINDOW_HEIGHT = 800

    IMAGE_BACKGROUND_COLOR = Fox::FXColor::Black

    HELP_TEXT = <<END_TEXT
#{APPLICATION} is a flip-book tool for SleepIsDeath (http://sleepisdeath.net).

Author: Spooner (Bil Bas)

Allows the user to view and edit flip- books.
END_TEXT

    def initialize(app)
      super(app, WINDOW_TITLE, :opts => DECOR_ALL,
             :width => DEFAULT_WINDOW_WIDTH, :height => DEFAULT_WINDOW_HEIGHT)

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
      @image_viewer.connect(SEL_LEFTBUTTONPRESS, method(:on_cmd_next))

      # Show info about the book and current frame.
      @info_bar = FXLabel.new(@main_frame, 'No flip-book loaded', nil, LAYOUT_FILL_X,
         :padLeft => 4, :padRight => 4, :padTop => 4, :padBottom => 4)

      add_button_bar(@main_frame)

      # Initialise various things.
      @current_directory = Dir.pwd
      @template_dir = Dir.pwd
      @current_frame_index = 0

      @thumb_viewers = [] # List of thumbnail viewing windows.
      @slide_show_interval = DEFAULT_SLIDE_SHOW_INTERVAL
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

      # Show menu.
      show_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, "&Show", nil, show_menu)
      @toggle_navigation_menu = FXMenuCheck.new(show_menu, "&Buttons\tCtrl-B\tHide/show navigation buttons.")
      @toggle_navigation_menu.connect(SEL_COMMAND, method(:on_toggle_nav_buttons_bar))
      @toggle_navigation_menu.checkState = true

      @toggle_info_menu = FXMenuCheck.new(show_menu, "&Information\tCtrl-I\tHide/show information about the book/frame.")
      @toggle_info_menu.connect(SEL_COMMAND, method(:on_toggle_info))
      @toggle_info_menu.checkState = true

      @toggle_status_menu = FXMenuCheck.new(show_menu, "Status bar\t\tHide/show status bar.")
      @toggle_status_menu.connect(SEL_COMMAND, method(:on_toggle_status_bar))
      @toggle_status_menu.checkState = true

      @toggle_thumbs_menu = FXMenuCheck.new(show_menu, "&Thumbnails\tCtl-T\tHide/show thumbnail strip.")
      @toggle_thumbs_menu.connect(SEL_COMMAND, method(:on_toggle_thumbs))
      @toggle_thumbs_menu.checkState = true

      # Options menu.
      options_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, "&Options", nil, options_menu)
      @options_menu = FXMenuCommand.new(options_menu, "Settings...\t\tView/set configuration.")
      @options_menu.connect(SEL_COMMAND) do |sender, selector, event|
        dialog = OptionsDialog.new(self)
        dialog.slide_show_interval = @slide_show_interval
        dialog.template_dir = @template_dir
        if dialog.execute == 1
          @slide_show_interval = dialog.slide_show_interval
          @template_dir = dialog.template_dir
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

    def show_message(type, caption, text)


      nil
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
      @play_button.connect(SEL_LEFTBUTTONPRESS, method(:play_button_pressed))
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
      @thumb_viewers.each do |viewer|
        @thumbs_row.removeChild(viewer)
      end
      @thumb_viewers.clear

      @book.frames.each_with_index do |frame, i|
        packer = FXVerticalFrame.new(@thumbs_row)
        image_view = FXImageView.new(packer, :opts => LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT,
                                      :width => THUMB_HEIGHT, :height => THUMB_HEIGHT)

        image_view.connect(SEL_LEFTBUTTONPRESS, method(:on_thumb_left_click))
        image_view.connect(SEL_RIGHTBUTTONPRESS, method(:on_thumb_right_click))

        label = FXLabel.new(packer, "#{i + 1}", :opts => LAYOUT_FILL_X)

        packer.create

        @thumb_viewers.push packer      
        
        img = FXPNGImage.new(getApp(), frame, IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP)
        img.create
        img.scale(THUMB_WIDTH, THUMB_HEIGHT)
        img.crop((THUMB_WIDTH - THUMB_HEIGHT) / 2, 0, THUMB_HEIGHT, THUMB_HEIGHT)

        image_view.image = img
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
      select_frame(@current_frame_index - 1)

      return 1
    end

    def play_button_pressed(sender, selector, event)
      @playing = !@playing

      if @playing
        @slide_show_timer = getApp().addTimeout(@slide_show_interval * 1000, method(:slide_show_timer))
        @play_button.text = '||'
        @play_button.tipText = "Pause slide-show"
      else
        @play_button.text = '|>'      
        @play_button.tipText = "Play slide-show"
      end

      return 1
    end

    def slide_show_timer(sender, selector, event)
      if @playing
        select_frame(@current_frame_index + 1)
        if @current_frame_index < @book.size - 1
          @slide_show_timer = getApp().addTimeout(@slide_show_interval * 1000, method(:slide_show_timer))
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
      img = FXPNGImage.new(getApp(), @book[@current_frame_index], IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP)
      img.create
      @image_viewer.image = img

      @info_bar.text = if @book.size > 0
        "Frame #{index + 1} of #{@book.size}"
      else
        "Empty flip-book"
      end

      @start_button.disable
      @previous_button.disable
      @play_button.disable
      @next_button.disable
      @end_button.disable      

      if index > 0
        @start_button.enable
        @previous_button.enable
      end

      if index < @book.size - 1
        @play_button.enable
        @end_button.enable
        @next_button.enable
      end

      nil
    end

    # Event when clicking on a thumbnail - select.
    def on_thumb_left_click(sender, selector, event)
      index = @thumb_viewers.index(sender.parent)
      select_frame(index)

      return 1
    end

    # Event when clicking on a thumbnail - delete.
    def on_thumb_right_click(sender, selector, event)
      index = @thumb_viewers.index(sender.parent)

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

      nil
    end

    # Open a new flip-book
    def on_cmd_open(sender, selector, event)
      open_dir = FXFileDialog.getOpenDirectory(self, "Open flip-book directory", @current_directory)
      begin
        getApp().beginWaitCursor do
          @book = Book.new(open_dir)
          show_frames
        end
        @current_directory = open_dir
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
      open_dir = FXFileDialog.getOpenDirectory(self, "Append flip-book directory", @current_directory)
      begin
        getApp().beginWaitCursor do
          # Append new frames and select the first one.
          new_frame = @book.size
          @book.append(Book.new(open_dir))
          show_frames(new_frame)
        end
        @current_directory = open_dir
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
      save_dir = FXFileDialog.getSaveFilename(self, "Save flip-book directory", @current_directory)
      if File.exists? save_dir
        dialog = FXMessageBox.new(self, "Save error!",
                 "File/folder #{save_dir} already exists, so flip-book cannot be saved.", nil,
                 MBOX_OK|DECOR_TITLE|DECOR_BORDER)
        dialog.execute
      else
        @current_directory = save_dir
        begin
          @book.write(@current_directory, @template_dir)
        rescue => ex
          dialog = FXMessageBox.new(self, "Save error!",
                 "Failed to save flipbook to #{@current_directory}, but failed because the template files found in #{@template_dir} were not valid. Use the menu Options->Settings to set a valid path to a flip-book templates directory.", nil,
                 MBOX_OK|DECOR_TITLE|DECOR_BORDER)
          dialog.execute
        end
      end

      return 1
    end

    # Quit the application
    def on_cmd_quit(sender, selector, event)
      # Write new window size back to registry
      getApp().reg().writeIntEntry("SETTINGS", "x", x)
      getApp().reg().writeIntEntry("SETTINGS", "y", y)
      getApp().reg().writeIntEntry("SETTINGS", "width", width)
      getApp().reg().writeIntEntry("SETTINGS", "height", height)

      # Current directory
      #getApp().reg().writeStringEntry("SETTINGS", "directory", @file_list.directory)

      # Quit
      getApp().exit(0)
    end

    def create
      # Get size, etc. from registry
      xx = getApp().reg().readIntEntry("SETTINGS", "x", 0)
      yy = getApp().reg().readIntEntry("SETTINGS", "y", 0)
      ww = getApp().reg().readIntEntry("SETTINGS", "width", DEFAULT_WINDOW_WIDTH)
      hh = getApp().reg().readIntEntry("SETTINGS", "height", DEFAULT_WINDOW_HEIGHT)

      #dir = getApp().reg().readStringEntry("SETTINGS", "directory", "~")
           
      # Reposition window to specified x, y, w and h
      position(xx, yy, ww, hh)

      # Create and show
      super   # i.e. FXMainWindow::create()
      show(PLACEMENT_SCREEN)

      return 1
    end

    def add_hot_keys
      accelTable.addAccel(fxparseAccel("Alt+F4"), self, FXSEL(SEL_CLOSE, 0))
    end
  end
end