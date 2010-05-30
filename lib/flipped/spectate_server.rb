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

    def initialize(port, name, options = {})
      @name = name
      @port = port

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
            log.info("Updating spectator ##{spectator.id}: #{spectator.name} (Frame ##{i + 1}, #{book[i].size} bytes)")
            spectator.send(Message::Frame.new(:frame => book[i]))
          end
        end
      end
    end

    def need_update?
      defined?(@joined_need_update) ?  @joined_need_update : false
    end

  protected
    # ------------------------
    #
    #

    def listen
      begin
        @server = TCPServer.new(@port)
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
    def add_spectator(socket)
      Thread.new(socket) do |socket|
        begin         
          spectator = Spectator.new(self, socket)

          spectator.send(Message::Challenge.new(:name => @name))

          @spectators.synchronize do
            log.info { "Spectator connected from #{socket.addr[3]}:#{socket.addr[1]}." }
            @spectators.push spectator
            @joined_need_update = true
          end
        rescue => ex
          log.error { ex }
        end
      end
    end
  end          
end