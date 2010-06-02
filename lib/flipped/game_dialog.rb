require 'book'
require 'dialog'

module Flipped

  # Dialog used when starting a game.
  class GameDialog < Dialog
    attr_reader :user_name
    def user_name # :nodoc:
      @user_name_target.value
    end

    attr_reader :time_limit
    def time_limit # :nodoc:
      @time_limit_target.value.to_i
    end

    def initialize(owner, translation, options)
      t = translation
      super(owner, t.title)

      # User name
      @user_name_label = FXLabel.new(@grid, t.user_name.label)
      @user_name_target = FXDataTarget.new(options[:user_name])
      @user_name_field = FXTextField.new(@grid, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_RIGHT|LAYOUT_FILL_X,
                      :target => @user_name_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @user_name_target.value
      end

      skip_grid
      skip_grid
      
      # Time limit
      FXLabel.new(@grid, t.time_limit)
      @time_limit_target = FXDataTarget.new(options[:time_limit].to_s)
      FXTextField.new(@grid, 6, :opts => TEXTFIELD_NORMAL|JUSTIFY_RIGHT|TEXTFIELD_INTEGER,
                      :target => @time_limit_target, :selector => FXDataTarget::ID_VALUE) do |widget|
        widget.text = @time_limit_target.value
      end

      skip_grid
      skip_grid

    end
  end
end