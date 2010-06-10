module Flipped
  # Manages the creation of menu bar and context menus in the Flipped::Gui.
  class Gui < FXMainWindow
    # Create the complete menu bar.
    #
    # === Parameters
    # +interval_range+:: Range of values allowed for slide-show interval.
    #
    # Returns: nil
    protected
    def create_menu_bar(interval_range)
      log.info { "Creating menu bar" }

      menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X|FRAME_RAISED)

      create_file_menu(menu_bar)
      create_sleep_is_death_menu(menu_bar)
      create_navigation_menu(menu_bar)
      create_edit_menu(menu_bar)
      create_view_menu(menu_bar)
      create_options_menu(menu_bar, interval_range)
      create_help_menu(menu_bar)

      nil
    end

    # Create the file menu.
    #
    # === Parameters
    # +menu_bar+:: Menu bar to place the menu panes on [FXMenuBar]
    #   
    # Returns: Created pane [FXMenuPane]
    protected
    def create_file_menu(menu_bar)
      file_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.file, nil, file_menu)

      create_menu(file_menu, :open)
      @append_menu = create_menu(file_menu, :append)

      FXMenuSeparator.new(file_menu)
      @save_menu = create_menu(file_menu, :save_as)
      FXMenuSeparator.new(file_menu)
      create_menu(file_menu, :quit)

      file_menu
    end

    # Create the SleepIsDeath menu.
    #
    # === Parameters
    # +menu_bar+:: Menu bar to place the menu panes on [FXMenuBar]
    #
    # Returns: Created pane [FXMenuPane]
    protected
    def create_sleep_is_death_menu(menu_bar)
      sid_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.sleep_is_death, nil, sid_menu)

      create_menu(sid_menu, :control_sid)
      create_menu(sid_menu, :play_sid)
      create_menu(sid_menu, :spectate_sid)

      FXMenuSeparator.new(sid_menu)

      create_menu(sid_menu, :my_ip_address)

      sid_menu
    end

    # Create the navigation menu.
    #
    # === Parameters
    # +menu_bar+:: Menu bar to place the menu panes on [FXMenuBar]
    #
    # Returns: Created pane [FXMenuPane]
    protected
    def create_navigation_menu(menu_bar)
      nav_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.navigate, nil, nav_menu)

      @start_menu = create_menu(nav_menu, :start)
      @previous_menu = create_menu(nav_menu, :previous)
      @play_menu = create_menu(nav_menu, :play)
      @next_menu = create_menu(nav_menu, :next)
      @end_menu = create_menu(nav_menu, :end)

      nav_menu
    end

    # Create the edit menu.
    #
    # === Parameters
    # +menu_bar+:: Menu bar to place the menu panes on [FXMenuBar]
    #
    # Returns: Created pane [FXMenuPane]
    protected
    def create_edit_menu(menu_bar)
      edit_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.edit, nil, edit_menu)

      @delete_menu = create_menu(edit_menu, :delete_single)
      @delete_before_menu = create_menu(edit_menu, :delete_before)
      @delete_after_menu = create_menu(edit_menu, :delete_after)
      @delete_identical_menu = create_menu(edit_menu, :delete_identical)

      edit_menu
    end

    # Create the view menu.
    #
    # === Parameters
    # +menu_bar+:: Menu bar to place the menu panes on [FXMenuBar]
    #
    # Returns: Created pane [FXMenuPane]
    protected
    def create_view_menu(menu_bar)
      view_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.view, nil, view_menu)

      zoom_menu = FXMenuPane.new(self)
      @zoom_menu = FXMenuCascade.new(view_menu, t.zoom, nil, zoom_menu)
      @zoom_target = FXDataTarget.new(ZoomOption::DEFAULT)
      @zoom_target.connect(SEL_COMMAND) do |sender, selector, option|
        zoom_level = case option
          when ZoomOption::HALF
            0.5
          when ZoomOption::ORIGINAL
            1
          when ZoomOption::DOUBLE
            2
        end
        resize_frame(zoom_level)
      end
      half = create_menu(zoom_menu, :view_half_size, FXMenuRadio)
      half.target = @zoom_target
      half.selector = FXDataTarget::ID_OPTION + ZoomOption::HALF
      original = create_menu(zoom_menu, :view_original_size, FXMenuRadio)
      original.target = @zoom_target
      original.selector = FXDataTarget::ID_OPTION + ZoomOption::ORIGINAL
      double = create_menu(zoom_menu, :view_double_size, FXMenuRadio)
      double.target = @zoom_target
      double.selector = FXDataTarget::ID_OPTION + ZoomOption::DOUBLE

      # Show sub-menu (on view)
      show_menu = FXMenuPane.new(self)
      FXMenuCascade.new(view_menu, t.show, nil, show_menu)
      @toggle_navigation_menu = create_menu(show_menu, :toggle_nav_buttons_bar, FXMenuCheck)
      @toggle_info_menu = create_menu(show_menu, :toggle_info, FXMenuCheck)
      @toggle_status_menu = create_menu(show_menu, :toggle_status_bar, FXMenuCheck)
      @toggle_thumbs_menu = create_menu(show_menu, :toggle_thumbs, FXMenuCheck)

      view_menu
    end

    # Create the options menu.
    #
    # === Parameters
    # +menu_bar+:: Menu bar to place the menu panes on [FXMenuBar]
    # +interval_range+:: Range of values allowed for slide-show interval.
    #
    # Returns: Created pane [FXMenuPane]
    protected
    def create_options_menu(menu_bar, interval_range)
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
      interval_range.each do |i|
        FXMenuRadio.new(interval_menu, "#{i}", :target => @slide_show_interval_target, :selector => FXDataTarget::ID_OPTION + i)
      end
      FXMenuCascade.new(options_menu, "#{t.interval.menu}\t\t#{t.interval.help}", :popupMenu => interval_menu)

      FXMenuSeparator.new(options_menu)

      create_menu(options_menu, :settings)
      
      options_menu
    end

    # Create the help menu.
    #
    # === Parameters
    # +menu_bar+:: Menu bar to place the menu panes on [FXMenuBar]
    #
    # Returns: Created pane [FXMenuPane]
    protected
    def create_help_menu(menu_bar)
      # Help menu
      help_menu = FXMenuPane.new(self)
      FXMenuTitle.new(menu_bar, t.help, nil, help_menu, LAYOUT_RIGHT)

      create_menu(help_menu, :about)

      help_menu
    end
    
    # Create a single menu item.
    #
    # === Parameters
    # +owner+:: Menu pane to place the menu item on [FXMenuPane]
    # +name+:: Name of the item [Symbol]
    # +type+:: Class of the item [Class]
    # +options+:: Options to pass on to the new instance in its constructor [Hash]
    #
    # Returns: Newly created menu item [whatever +type+ is]
    protected
    def create_menu(owner, name, type = FXMenuCommand, options = {})
      text = [t[name].menu, @key[name], t[name].help(@key[name])].join("\t")
      menu = type.new(owner, text, options)
      menu.connect(SEL_COMMAND, method(:"on_cmd_#{name}")) unless type == FXMenuRadio

      menu
    end

    # Create a context menu for a frame image, allowing deletion of it and other frames.
    #
    # === Parameters
    # +index+:: Index of frame to create menu for [Integer]
    # +x+:: X position of mouse [Float]
    # +y+:: Y position of mouse [Float]
    #
    # Returns: nil
    protected
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
  end
end