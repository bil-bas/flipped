require 'thread'
require 'socket'
require 'logger'
require 'base64'

require 'json'

require 'spectate_server'
require 'packet'

# =============================================================================
#
#
module Flipped
  class SpectateClient
    include Packet
    
    DEFAULT_PORT = SpectateServer::DEFAULT_PORT
    
    attr_reader :log, :socket

    def initialize(address, port, name, options = {})
      @address, @port, @name = address, port, name

      log_to = options[:log_to] || STDOUT
      @log = Logger.new(log_to)
      @log.progname = self.class.name

      @length = nil
      @buffer = ''

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
      @frames.synchronize do
        frames = @frames.dup
        @frames.clear
      end
      frames
    end

  protected
    def read()
      @frames = []
      @frames.extend(Mutex_m)

      begin
        until socket.closed?
          length = @socket.read(4)
          break unless length
          length = length.unpack('L')[0]

          packet = @socket.read(length)
          break unless packet
          packet = JSON.parse(packet)

          case packet[Tag::TYPE]
            when Type::FRAME
              frame_data = Base64.decode64(packet[Tag::DATA])
              log.info { "Received frame (#{frame_data.size} bytes)" }
              @frames.synchronize do
                @frames.push frame_data
              end

            when Type::SERVER_INIT
              @server_name = packet[Tag::NAME]
              log.info { "Server at #{@address}:#{@port} identified as #{@server_name}." }

              packet = { Tag::TYPE => Type::CLIENT_INIT, Tag::NAME => @name }.to_json
              @socket.write([packet.length].pack('L'))
              @socket.write(packet)
              @socket.flush

            else
              log.error { "Unrecognised packet type: #{packet[Tag::TYPE]}" }
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