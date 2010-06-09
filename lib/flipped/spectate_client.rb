require 'thread'
require 'socket'

require 'log'
require 'spectate_server'
require 'message'

# =============================================================================
#
#
module Flipped
  class SpectateClient
    include Log

    # Time that the Player first received a frame [Time].
    attr_reader :story_started_at
    # Name that the Controller gave to the story [String].
    attr_accessor :story_name

    protected    
    def initialize(address, port, name, role, time_limit)
      @address, @port, @name, @role, @time_limit = address, port, name, role, time_limit

      @player, @controller = nil, nil
      @spectators = Array.new
      @story_started_at = nil
      @story_name = DEFAULT_STORY_NAME

      connect

      nil
    end

    public
    attr_reader :controller_name
    def controller_name # :nodoc:
      @controller ? @controller.name : DEFAULT_NAME
    end

    public
    attr_reader :controller_time_limit
    def controller_time_limit # :nodoc:
      @controller ? @controller.time_limit : DEFAULT_TIME_LIMIT
    end

    public
    attr_reader :player_name
    def player_name # :nodoc:
      @player ? @player.name : DEFAULT_NAME
    end

    public
    attr_reader :player_time_limit
    def player_time_limit # :nodoc:
      @player ? @player.time_limit : DEFAULT_TIME_LIMIT
    end

    public
    def closed?
      @socket.closed?
    end

    #
    #
    public
    def close
      @socket.close unless @socket.closed?

      nil
    end

    protected
    def read()
      @frames_buffer = []
      @frames_buffer.extend(Mutex_m)

      begin
        until @socket.closed?
          message = Message.read(@socket)
          case message
            when Message::Frame
              frame_data = message.frame
              log.info { "Received frame (#{frame_data.size} bytes)" }
              if defined? @on_frame_received
                @on_frame_received.call(frame_data)
              end

            when Message::Challenge
              log.info { "Server at #{@address}:#{@port} identified as #{@player_name}." }

              Message::Login.new(:name => @name, :role => @role, :time_limit => @time_limit, :version => VERSION).write(@socket)

            when Message::Accept
              log.info { "Login accepted" }
              if message.renamed_as
                @name = message.renamed_as
              end

              # If the controller has logged in, update everyone else with the name of the story.
              if @role == :controller and @story_name
                 Message::StoryNamed.new(:name => @story_name).write(@socket)
              end

            when Message::Connected
              case message.role
                when :controller
                  @controller = message
                  log.info { "Controller '#{@controller.name}' connected with #{@controller.time_limit}s turns." }
                when :player
                  @player = message
                  log.info { "Player '#{@player.name}' connected with #{@player.time_limit}s turns." }
                else
                  log.info { "Spectator '#{message.name}' connected." }
              end
              
              @spectators.push message

            when Message::Disconnected
              to_remove = @spectators.find {|s| s.id == message.id }
              @spectators.delete(to_remove)
              @controller = nil if to_remove.id == @controller.id
              @player = nil if to_remove.id == @player.id
              log.info { "Spectator '#{to_remove.name}' disconnected." }

            when Message::StoryNamed
              @story_name = message.name
              log.info { "Story named as '#{@story_name}'" }

            when Message::StoryStarted
              @story_started_at = message.started_at
              log.info { "Story '#{@story_name}' started at '#{@story_started_at}'" }
              if defined? @on_story_started
                @on_story_started.call(@story_name, @story_started_at)
              end

            when Message::SiDStarted
              log.info { "SiD started by '#{@controller.name}' on port '#{message.port}'" }
              if defined? @on_sid_started
                @on_sid_started.call(message.port)
              end

            else
              log.error { "Unrecognised message type: #{message.class}" }
          end
        end
      rescue IOError, SystemCallError => ex
        log.error { "Failed to read message."}
        log.error { ex }
        close
      end

      nil
    end

    # Register event handler for a story starting (first frame written out by player).
    public
    def on_story_started(method = nil, &block)
      @on_story_started = if block
        block
      else
        method
      end

      nil
    end

    # Register event handler for a frame being received.
    public
    def on_frame_received(method = nil, &block)
      @on_frame_received = if block
        block
      else
        method
      end

      nil
    end

    # Register event hander for SiD being started on the controller machine.
    def on_sid_started(method = nil, &block)
      @on_sid_started = if block
        block
      else
        method
      end

      nil
    end

    # ONLY ON THE PLAYER client.
    public
    def send_frames(frames)
      log.info { "Sending #{frames.size} frames to server."}

      frames.each do |frame|
        send(Message::Frame.new(:frame => frame))
      end
  
      nil
    end

    # ONLY ON THE PLAYER client.
    public
    def send_story_started
      @story_started_at = Time.now
      send(Message::StoryStarted.new(:started_at => @story_started_at))

      @story_started_at
    end

    public
    def send(message)
      begin
        message.write(@socket)
      rescue IOError, SystemCallError => ex
        log.error { "Failed to send message."}
        log.error { ex }
        close
      end

      nil
    end

    #
    #
    protected
    def connect()
      @socket = TCPSocket.open(@address, @port)

      log.info { "Connected to #{@address}:#{@port}." }

      Thread.new { read }
      
      nil
    end
  end
end