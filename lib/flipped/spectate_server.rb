require 'thread'
require 'socket'
require 'mutex_m'
require 'logger'

# =============================================================================
#
#
module Flipped
  class SpectateServer   

    DEFAULT_PORT = 7777
    DEFAULT_AUTO_SAVE = true

    attr_reader :log

    def initialize(port, name, options = {})
      log_to = options[:log_to] || STDOUT
      @name = name
      @port = port

      @log = Logger.new(log_to)
      @log.progname = self.class.name

      srand

      @spectators = []
      @spectators.extend(Mutex_m)
      @server = nil
      @listen_thread = nil
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

    # Bring all spectators up to the current frame.
    def update_spectators(book)
      log.info("Updating spectators")
      @joined_need_update = false
      @spectators.synchronize do
        @spectators.dup.each do |spectator|
          # Update with all previous messages.

          ((spectator.position + 1)...book.size).each do |i| 
            log.info("Updating spectator ##{spectator.id}: #{spectator.name} (Frame ##{i + 1})")
            send_frame(spectator, book[i])
          end
        end
      end
    end

    def need_update?
      defined?(@joined_need_update) ?  @joined_need_update : false
    end

  protected
    class Spectator
      attr_reader :name, :socket, :id
      attr_accessor :position

      @@next_spectator_id = 1

      def initialize(name, socket)
        @name, @socket = name, socket
        @position = -1
        @id = @@next_spectator_id
        @@next_spectator_id += 1
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

      nil
    end

    # Add a new spectator associated with a particular socket.
    def add_spectator(socket)
      Thread.new(socket) do |socket|
        begin
          spectator_name = socket.gets.strip
          spectator = Spectator.new(spectator_name, socket)

          spectator.socket.puts @name
          spectator.socket.flush
          @spectators.synchronize do
            log.info { "#{spectator_name} connected from #{socket.addr[3]} on port #{socket.addr[1]}." }
            @spectators.push spectator
            @joined_need_update = true
          end
        rescue => ex
          p ex
        end
      end
    end

    # Send a particular book frame to a particular spectator.
    def send_frame(spectator, frame)
        socket = spectator.socket
        return if socket.closed?

        begin
          socket.write([frame.size].pack('L'))
          socket.write(frame)
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