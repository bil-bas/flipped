require 'thread'
require 'socket'
require 'logger'
require 'zlib'

require 'json'

require 'spectate_server'
require 'message'

# =============================================================================
#
#
module Flipped
  class SpectateClient
    DEFAULT_PORT = SpectateServer::DEFAULT_PORT
    
    attr_reader :log, :socket

    def initialize(address, port, name, options = {})
      @address, @port, @name = address, port, name

      log_to = options[:log_to] || STDOUT
      @log = Logger.new(log_to)
      @log.progname = self.class.name

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
          length = @socket.read(4)
          break unless length
          length = length.unpack('L')[0]

          packet = @socket.read(length)
          break unless packet
          packet = JSON.parse(Zlib::Inflate.inflate(packet))

          case packet
            when Message::Frame
              frame_data = packet.frame
              log.info { "Received frame (#{frame_data.size} bytes)" }
              @frames_buffer.synchronize do
                @frames_buffer.push frame_data
              end

            when Message::Challenge
              @server_name = packet.name
              log.info { "Server at #{@address}:#{@port} identified as #{@server_name}." }

              packet = Message::Login.new(:name => @name).to_json
              @socket.write([packet.length].pack('L'))
              @socket.write(packet)
              @socket.flush

            when Message::Accept
              log.info { "Login accepted" }

            else
              log.error { "Unrecognised packet type: #{packet.class}" }
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