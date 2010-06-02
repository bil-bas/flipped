require 'thread'
require 'socket'
require 'mutex_m'

require 'log'
require 'message'
require 'spectator'

# =============================================================================
#
#
module Flipped
  class SpectateServer
    include Log
    
    DEFAULT_PORT = 7777
    DEFAULT_AUTO_SAVE = true
    DEFAULT_NAME = '?'
    DEFAULT_TIME_LIMIT = 0
    
    protected
    def initialize(port, broadcasting)
      @port, @broadcasting =  port, broadcasting

      srand

      @spectators = Array.new
      @spectators.extend(Mutex_m)
      
      @server = nil
      @listen_thread = nil

      # Frame messages received from the player, ready to send to
      # spectators and controller.
      @frames = Array.new
      @frames.extend(Mutex_m)

      @controller = nil
      @player = nil

      Thread.abort_on_exception = true

      listen

      nil
    end

    # ------------------------
    #
    #
    public
    def close
      @server.close unless @server.closed?
      @listen_thread.join

      @spectators.synchronize do
        @spectators.each { |s| s.close }
        @spectators.clear
      end

      nil
    end

    # Bring all spectators up to the current frame.
    protected
    def update_spectators
      log.info("Updating spectators")
      @spectators.synchronize do
        @spectators.dup.each do |spectator|
          # Update with all previous frames, except the player, who sends us frames.
          if spectator.logged_in? and not spectator.player?
            update_spectator(spectator)
          end
        end
      end
      
      nil
    end

    protected
    def update_spectator(spectator)
      @frames.synchronize do
        ((spectator.position + 1)...@frames.size).each do |i|
          log.info("Updating spectator ##{spectator.id}: #{spectator.name} (Frame ##{i + 1})")
          spectator.send(@frames[i])
        end
      end
    end

    # Called from the spectator itself.
    public
    def disconnect_spectator(spectator)
      return if @server.closed?

      message = Message::Disconnected.new(:id => spectator.id)
      @spectators.synchronize do
        @spectators.delete spectator
        @spectators.each do |other|
          other.send(message) if other.logged_in?
        end
      end

      nil
    end

    protected
    def wait_for_frame_updates
      Thread.new do
        log.info { "Started waiting for player frame updates"}
        begin
          loop do
            case message = Message.read(@player.socket)
              when Message::Frame
                @frames.synchronize do
                  @frames.push message
                end

                update_spectators
            end
          end
        rescue Exception => ex
          log.error { "Problem when waiting for frame updates."}
          log.error { ex }
        end
      end
    end

    # Called from the spectator itself.
    public
    def connect_spectator(spectator)
      spectator.send(Message::Accept.new)

      case spectator.role
        when :player
          @player = spectator
          wait_for_frame_updates
        when :controller
          @controller = spectator
      end

      message = Message::Connected.new(:name => spectator.name, :id => spectator.id, :role => spectator.role, :time_limit => spectator.time_limit)
      spectator.send(message) # Remind them about themselves first.
      @spectators.synchronize do
        @spectators.each do |other|
          if other.logged_in?
            # Make sure everyone else knows about the newly connected spectator.
            other.send(message)
            # Make sure the newly connected spectator knows about everyone already logged in.
            spectator.send(Message::Connected.new(:name => other.name, :id => other.id, :role => other.role, :time_limit => other.time_limit))
          end
        end

        update_spectator(spectator) unless spectator.player?
      end

      nil
    end

    #
    #
    protected
    def listen
      begin
        @server = if @broadcasting
          TCPServer.new(@port) # Allow remote connections.
        else
          TCPServer.new('localhost', @port) # Don't allow remote connections.
        end
      rescue Exception => ex
        raise Exception.new("#{self.class} failed to start on port #{@port}! #{ex}")
      end

      log.info { "#{@name} waiting for a connection on port #{@port}." }

      @listen_thread = Thread.new do
        begin
          while socket = @server.accept
            add_spectator(socket)
          end
        rescue Exception => ex
          log.error { ex }
          @server.close unless @server.closed?
        end
      end

      nil
    end

    # Add a new spectator associated with a particular socket.
    protected
    def add_spectator(socket)
      Thread.new(socket) do |socket|
        begin         
          spectator = Spectator.new(self, socket)

          @spectators.synchronize do
            log.info { "Spectator connected from #{socket.addr[3]}:#{socket.addr[1]}." }
            @spectators.push spectator
          end
        rescue => ex
          log.error { ex }
        end
      end
    end
  end          
end