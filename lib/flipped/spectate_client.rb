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
    
    DEFAULT_PORT = SpectateServer::DEFAULT_PORT
    DEFAULT_NAME = SpectateServer::DEFAULT_NAME
    DEFAULT_TIME_LIMIT = SpectateServer::DEFAULT_TIME_LIMIT

    attr_reader :socket

    protected    
    def initialize(address, port, name, role, time_limit)
      @address, @port, @name, @role, @time_limit = address, port, name, role, time_limit

      @player, @controller = nil, nil
      @spectators = Array.new
      @story = nil

      Thread.abort_on_exception = true

      connect

      nil
    end

    public
    def controller_name
      @controller ? @controller.name : DEFAULT_NAME
    end

    public
    def controller_time_limit
      @controller ? @controller.time_limit : DEFAULT_TIME_LIMIT
    end

    public
    def player_name
      @player ? @player.name : DEFAULT_NAME
    end

    public
    def player_time_limit
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

    public
    def frames_buffer
      frames = nil
      @frames_buffer.synchronize do
        frames = @frames_buffer.dup
        @frames_buffer.clear
      end
      
      frames
    end
    
    protected
    def read()
      @frames_buffer = []
      @frames_buffer.extend(Mutex_m)

      begin
        until socket.closed?
          message = Message.read(socket)
          case message
            when Message::Frame
              frame_data = message.frame
              log.info { "Received frame (#{frame_data.size} bytes)" }
              @frames_buffer.synchronize do
                @frames_buffer.push frame_data
              end

            when Message::Challenge
              log.info { "Server at #{@address}:#{@port} identified as #{@player_name}." }

              Message::Login.new(:name => @name, :role => @role, :time_limit => @time_limit).write(socket)

            when Message::Accept
              log.info { "Login accepted" }
              if message.renamed_as
                @name = message.renamed_as
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

            when Message::Story
              @story = message
              log.info { "Story '#{@story.name}' started at #{@story.started_at}" }          
              @frames_buffer.clear

            else
              log.error { "Unrecognised message type: #{message.class}" }
          end
        end
      rescue IOError, Errno::ECONNABORTED
        close
      end

      nil
    end

    # ONLY ON THE PLAYER client.
    public
    def send_frames(frames)
      log.info { "Sending #{frames.size} frames to server."}
      frames.each do |frame|
        Message::Frame.new(:frame => frame).write(@socket)
      end
      
      nil
    end

    #
    #
    protected
    def connect()
      # Connect to a server

      @socket = TCPSocket.open(@address, @port)

      log.info { "Connected to #{@address}:#{@port}." }

      Thread.new { read }
      
      nil
    end
  end
end