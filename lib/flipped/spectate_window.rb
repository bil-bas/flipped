require 'fox16'
include Fox

module Flipped
  class SpectateWindow < FXMainWindow

    class UserList < FXList
      class User < FXListItem
        attr_reader :role, :id, :name

        public
        def name=(name)
          @name = name

          self.text = case @role
            when :controller
              "#{name} (C)"
            when :player
              "#{name} (P)"
            else
              name
          end

          @list.sortItems

          name
        end

        public
        def role=(role)
          @role = role
          @list.set_role_icon(id, @role)
          
          role
        end

        public
        def create
          super
          @list.set_role_icon(id, @role)
        end

        protected
        def initialize(list, id, name, role)
          super('')
          @list = list
          @role = role
          @id = id          
          self.name = name

          nil
        end

        public
        def <=>(other)
          name.downcase <=> other.name.downcase
        end
      end

      # Get the user by id.
      public
      def [](id)
        find_user_by_id(id)
      end

      public
      def add_user(name, id, role)
        appendItem(User.new(self, name, id, role))
        sortItems

        nil
      end

      def remove_user(id)
        user = find_user_by_id(id)
        removeItem(user) if user

        nil
      end

      def find_user_by_id(id)
        each {|user| return user if user.id == id }
        nil
      end

      # Only for use by internal User class.
      public
      def set_role_icon(id, role)
        # TODO: set icon based on role
      end
    end

    # Translation strings.
    attr_reader :t

    protected
    def initialize(app, translations)
      @t = translations
      super(app, t.initial_title, :x => 100, :y => 100, :width => 400, :height => 400)
      main_frame = FXSplitter.new(self, :opts => SPLITTER_TRACKING|LAYOUT_FILL)

      add_chat_frame(main_frame)

      add_user_frame(main_frame)

      @on_chat_input = nil # Handler for when local user enters a chat string.
      @player_id = nil # ID of the local player.

      nil
    end

    protected
    def add_chat_frame(frame)
      chat_frame = FXVerticalFrame.new(frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y)
      @chat_output = FXText.new(chat_frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y) do |widget|
        widget.editable = false      
      end      

      @chat_input = FXTextField.new(chat_frame, 1, :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X) do |widget|
        widget.connect(SEL_COMMAND) do |sender, selector, text|
          if @player_id
            @on_chat_input.call(@player_id, nil, text) if @on_chat_input
            chat(@player_id, nil, text)
            sender.text = ''
          end
        end
      end

      nil
    end

    protected
    def add_user_frame(frame)
      user_frame = FXVerticalFrame.new(frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_FIX_WIDTH)
      @user_list = UserList.new(user_frame, :opts => LIST_SINGLESELECT|LAYOUT_FILL_X|LAYOUT_FILL_Y)

      nil
    end

    public
    def on_chat_input(method = nil, &block)
      @on_chat_input = block ? block : method

      nil
    end

    public
    def chat(from, to, text)
      name = @user_list[from].name
      if to
        @chat_output.appendText("#{t.message.whispers(name, text)}\n")
      else
        @chat_output.appendText("#{t.message.says(name, text)}\n")
      end

      nil
    end

    public
    def user_connected(id, name, role)
      if @player_id
        @chat_output.appendText("#{t.message.connected(name, t.role[role])}\n")
      else
        @player_id = id 
      end
      @user_list.add_user(id, name, role)

      nil
    end

    public
    def user_disconnected(id)
      @chat_output.appendText("#{t.message.disconnected(name)}\n")
      @user_list.remove_user(id)
      
      nil
    end

    public
    def [](id)
      @user_list[id]

      nil
    end
  end
end