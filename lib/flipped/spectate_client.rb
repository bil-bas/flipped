require 'thread'
require 'socket'
require 'logger'

require 'book'
require 'spectate_server'

# =============================================================================
#
#
module Flipped
  class SpectateClient
    DEFAULT_NAME = 'Player'
    
    attr_reader :log

    def initialize(flip_book_dir, template_dir, address, options = {})
      @log = Logger.new(STDOUT)
      @log.progname = self.class.name

      @name = options[:name] || DEFAULT_NAME
      port = options[:port] || SpectateServer::DEFAULT_PORT

      srand
      
      Thread.abort_on_exception = true

      connect(flip_book_dir, template_dir, address, port)
    end

    def reading?
      @reading
    end

    def closed?
      @socket.closed?
    end

    def size
      @book.synchronize do
        @book.size
      end
    end

    # ------------------------
    #
    #

    def close
      @socket.close unless @socket.closed?
      @reading = false
      @read_thread.join
    end

  protected
    # ------------------------
    #
    #
    def connect(flip_book_dir, template_dir, address, port)
      # Connect to a server
      @socket = TCPSocket.new(address, port)
      @socket.puts @name
      @socket.flush

      server_name = @socket.gets.strip

      log.info { "#{self.class}: Connected to #{server_name} (#{address}:#{port})." }

      @book = Book.new
      @book.extend(Mutex_m)

      @reading = true
      @read_thread = Thread.new do
        begin
          while reading? && (length = @socket.read(4))
            length = length.unpack('L')[0]

            buffer = ''
            while reading? && buffer.length < length
              buffer += @socket.read(length - buffer.size)
              log.debug { buffer.length }
            end

            if buffer.length == length
              @book.synchronize do
                @book.insert(@book.size, buffer)
                dir = "#{flip_book_dir}_#{@book.size} frames"
                @book.write(dir, template_dir)
                log.info { "#{@name} wrote book to #{dir}" }
              end

            end
          end
        rescue Exception => ex
          log.info { "#{@name} disconnected #{ex}"}
        end
      end

      nil
    end
  end
end