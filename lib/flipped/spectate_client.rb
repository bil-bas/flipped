require 'thread'
require 'socket'
require 'logger'

require 'spectate_server'

# =============================================================================
#
#
module Flipped
  class SpectateClient
    DEFAULT_PORT = SpectateServer::DEFAULT_PORT
    DEFAULT_NAME = 'Player'
    
    attr_reader :log, :socket

    def initialize(address, options = {})
      log_to = options[:log_to] || STDOUT
      @name = options[:name] || DEFAULT_NAME
      port = options[:port] || DEFAULT_PORT

      @log = Logger.new(log_to)
      @log.progname = self.class.name

      @length = nil
      @buffer = ''

      srand
      
      Thread.abort_on_exception = true

      connect(address, port)
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

          frame = @socket.read(length)
          break unless frame
          @frames.synchronize do
            @frames.push frame
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
    def connect(address, port)
      # Connect to a server

      @socket = TCPSocket.open(address, port)
      @socket.puts @name
      @socket.flush

      server_name = @socket.gets.strip

      log.info { "#{self.class}: Connected to #{server_name} (#{address}:#{port})." }

      Thread.new { read }
      
      nil
    end
  end
end