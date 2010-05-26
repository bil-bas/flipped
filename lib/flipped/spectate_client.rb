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
    attr_reader :socket

    def initialize(address, port, name, options = {})
      @address, @port, @name = address, port, name

      srand
      
      Thread.abort_on_exception = true

      connect
    end

    def closed?
      @socket.closed?
    end

    # ------------------------
    #
    #

    def close
      @socket.close unless @socket.closed?
    end

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
              @server_name = message.name
              log.info { "Server at #{@address}:#{@port} identified as #{@server_name}." }

              Message::Login.new(:name => @name).write(socket)

            when Message::Accept
              log.info { "Login accepted" }

            else
              log.error { "Unrecognised message type: #{message.class}" }
          end
        end
      rescue IOError
        close
      end

      nil
    end

    # ------------------------
    #
    #
    def connect()
      # Connect to a server

      @socket = TCPSocket.open(@address, @port)

      log.info { "Connected to #{@address}:#{@port}." }

      Thread.new { read }
      
      nil
    end
  end
end