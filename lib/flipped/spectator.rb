require 'log'
require 'message'

module Flipped
  class Spectator
    include Log
    
    INITIAL_POSITION = -1
    ROLES = [:controller, :player, :spectator] # initially nil.

    attr_reader :socket, :id, :time_limit, :role, :name, :position

    @@next_spectator_id = 1

    public
    def logged_in?; @logged_in; end
    def controller?; @role == :controller; end
    def player?; @role == :player; end
    def spectator?; @role == :spectator; end

    protected
    def initialize(server, socket)
      @server, @socket = server, socket

      @name = nil
      @position = INITIAL_POSITION
      @time_limit = nil # Implies that this isn't the controller
      @logged_in = false
      @role = nil
      
      @id = @@next_spectator_id
      @@next_spectator_id += 1

      Thread.new do
        begin
          send(Message::Challenge.new)
          
          message = Message.read(@socket)
          case message
            when Message::Login
              @name = message.name
              @role = message.role
              raise Exception.new("Unrecognised role: '#{@role.inspect}'") unless ROLES.include? @role
              @time_limit = message.time_limit
              # TODO: Check password.

              @server.connect_spectator(self)

              log.info { "#{@socket.addr[3]}:#{@socket.addr[1]} identified as #{@name}." }
              @logged_in = true            
            else
              # Ignore.
          end
        rescue Exception => ex
          log.error { "#{@name} died unexpectedly while reading." }
          log.error { ex }
          close
        end
      end
    end

    public
    def close
      @socket.close unless @socket.closed?
      log.info { "Spectator '#{name}' disconnected." }
      @server.disconnect_spectator(self) if logged_in?
      @logged_in = false
    end

    # Send a particular packet.
    public
    def send(message)
      return if @socket.closed?
      begin
        size = message.write(@socket)
      rescue => ex
        log.error { "#{@name} died unexpectedly while writing" }
        log.error { ex }
        @socket.close unless @socket.closed?
      end

      # If a frame is being sent, then increment our own position.
      case message
        when Message::Frame
          @position += 1

        when Message::Story
          @position = INITIAL_POSITION
      end

      size
    end
  end
end