require 'thread'
require 'socket'
require 'mutex_m'
require 'logger'

require 'book'

# =============================================================================
#
#
module Flipped
  class SpectateServer   
    CHECK_INTERVAL = 0.5 # 0.5s between checking for file-write.

    DEFAULT_PORT = 7777
    DEFAULT_NAME = 'Controller'
    DEFAULT_AUTO_SAVE = true

    attr_reader :log

    def initialize(flip_book_dir, options = {})
      @log = Logger.new(STDOUT)
      @log.progname = self.class.name
      
      @name = options[:name] || DEFAULT_NAME
      @auto_save = options[:auto_save] || true
      @port = options[:port] || DEFAULT_PORT

      srand

      @flip_book_dir = flip_book_dir
      @spectators = []
      @spectators.extend(Mutex_m)
      @server = nil
      @listen_thread = nil
      @read_thread = nil
      @book = nil

      Thread.abort_on_exception = true

      listen

      nil
    end

    # ------------------------
    #
    #
    def close
      @reading = false

      @server.close unless @server.closed?

      @spectators.synchronize do
        @spectators.each { |s| s.socket.close }
        @spectators.clear
      end

      @listen_thread.join
    end

  protected
    class Spectator
      attr_reader :name, :socket
      attr_accessor :position

      def initialize(name, socket)
        @name, @socket = name, socket
        @position = -1
      end
    end
    
    # ------------------------
    #
    #

    def listen
      begin
        @server = TCPServer.new('localhost', @port)
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
          @server.close unless @server.closed?
        end
      end

      @book = Book.new
      @book.extend(Mutex_m)
      @read_thread = Thread.new do
        @reading = true
        while @reading
          new_book = Book.new(@flip_book_dir)

          update = false
          @book.synchronize do
            if new_book.size > @book.size
              (@book.size...new_book.size).each do |i|
                @book.insert(@book.size, new_book[i])
              end
              update = true
            end
          end
          update_spectators if update

          sleep CHECK_INTERVAL
        end
      end

      nil
    end

    # Add a new spectator associated with a particular socket.
    def add_spectator(socket)
      Thread.new(socket) do |socket|
        spectator_name = socket.gets.strip
        spectator = Spectator.new(spectator_name, socket)

        spectator.socket.puts @name
        spectator.socket.flush
        @spectators.synchronize do
          log.info { "#{spectator_name} connected from #{socket.addr[3]} on port #{socket.addr[1]}." }
          @spectators.push spectator
        end
        update_spectators
      end
    end

    # Bring all spectators up to the current frame.
    def update_spectators
      @spectators.synchronize do
        @spectators.dup.each do |spectator|
          # Update with all previous messages.
          @book.synchronize do
            ((spectator.position + 1)...@book.size).each do |i|
              send_frame(spectator, i)
            end
          end
        end
      end
    end

    # Send a particular book frame to a particular spectator.
    def send_frame(spectator, index)
        socket = spectator.socket
        return if socket.closed?

        data = @book[index]

        begin
          socket.write([data.size].pack('L'))
          socket.write(data)
          socket.flush
          spectator.position += 1
        rescue Exception => ex
          log.error { "#{spectator.name} died (#{ex.message})." }
          socket.close unless socket.closed?
          @spectators.delete(spectator)
        end
    end
  end          
end