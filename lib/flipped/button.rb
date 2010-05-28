require 'fox16'
include Fox

module Flipped
  class Button < Fox::FXButton
    H_PAD = 10
    V_PAD = 2.5
    
    def initialize(*args)
      unless args.last.is_a? Hash
        args.push Hash.new
      end

      options = args.last

      opts = options[:opts] || 0
      opts |= FRAME_RAISED|FRAME_THICK
      options[:opts] = opts

      options[:padLeft] = options[:padRight] = H_PAD
      options[:padTop] = options[:padBottom] = V_PAD

      super(*args)
    end
  end
end