require 'defaults'

module Flipped
  # Commands on the file menu in the Flipped::Gui class.
  class Gui < FXMainWindow
    # Open a new flip-book.
    protected
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

    # Append a flip-book onto an already loaded flip-book.
    protected
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

    # Save this flip-book
    protected
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
    protected
    def on_cmd_quit(sender, selector, event)
      disable_monitors

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
  end
end