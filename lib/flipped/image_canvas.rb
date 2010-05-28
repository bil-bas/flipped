require 'fox16'
include Fox

module Flipped
  # A window that holds an image that re-sizes to the size of the canvas.
  class ImageCanvas < FXCanvas
  protected
    def initialize(*args)
      @image_data = nil
      @back_buffer = nil
      @update_call_back = nil

      super(*args)
    end

  public
    attr_reader :image_width, :image_height

    # Set the image data.
    def data=(data)
      @image_data = data
      create_back_buffer
      update

      data
    end

    # Register a call-back block that is called with |image_width, image_height, zoom_width|
    # whenever the image is updated. 
    def on_update(&block)
      @update_call_back = block
    end

  protected
    # Create a correctly sized image, to blit onto the window when required.
    def create_back_buffer
      if @image_data.nil?
        @back_buffer = nil
      else
        @back_buffer = FXPNGImage.new(app, @image_data, :opts => IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP)
        @back_buffer.create

        @image_width, @image_height = @back_buffer.width, @back_buffer.height

        # Crop down to square.
        @back_buffer.crop((@back_buffer.width - @back_buffer.height) / 2, 0, @back_buffer.height, @back_buffer.height)

        # Re-size to fit in the window.
        size = [height, width].min
        @back_buffer.scale(size, size, 0) # Low quality, pixelised.
        @update_call_back.call(@image_width, @image_height, size) if @update_call_back
      end

      nil
    end

  public
    def create
      super

      @old_width, @old_height = width, height

      connect(SEL_PAINT) do |sender, selector, event|
        FXDCWindow.new(self, event) do |dc|
          # Fill with background, so the edges are not seen.
          dc.foreground = backColor
          dc.fillRectangle(event.rect.x, event.rect.y, event.rect.w, event.rect.h)

          # Draw the image buffer over the top.
          if @back_buffer
            dc.drawImage(@back_buffer, (width - @back_buffer.width) / 2, (height - @back_buffer.height) / 2)
          end
        end
      end

      connect(SEL_CONFIGURE) do |sender, selector, event|
        # Only create a new buffer if we have re-sized the window.
        if width > 1 and height > 1
          if width != @old_width or height != @old_height
            create_back_buffer
          end
          @old_width, @old_height = width, height
        end
      end
    end
  end
end