require 'thread'
require 'socket'

require 'book'

# =============================================================================
#
#
module Flipped
  class SpectateServer

    PORT = 7778
    CHECK_INTERVAL = 1 # 1s between checking for file-write.
    MAX_LEN = 0xFFFF

    def initialize(book_directory)

      srand

      @mutex = Mutex.new
      @spectators = []

      Thread.abort_on_exception = true
    end

    # ------------------------
    #
    #
    def start
      thread = listen(PORT)
      thread.join if thread

      nil
    end

    # ------------------------
    #
    #
    private
    def listen(port)
      # Create server
      begin
        server = TCPServer.new('localhost', port)
      rescue Exception => ex
        puts "TCPServer failed! #{ex}"
        return nil
      end

      puts "Waiting for a connection on port #{PORT}."

      return Thread.new do
        begin
          while sock = server.accept
            @mutex.synchronize do
              @spectators.push sock
            end
          end
        rescue Exception => ex
          puts "TCPServer failed! #{ex.class}: #{ex}\n#{ex.backtrace.join("\n")}"
          server.close
        end
      end
    end

    # ------------------------
    #
    #
    private
    def addPlayer(sock)
      Thread.new do
        begin

          loop do
            message = sock.read_bytes(MAX_LEN)

            # Make sure only one message is processed at a time.
            @mutex.synchronize do
              processMsg message, sock
            end
          end

        rescue IOError, NoMethodError => ex
          puts "Socket died: " + ex.inspect
        ensure
          kill sock
        end
      end
    end

    # ------------------------
    #
    #
    private
    def broadcast(frame)
      # Broadcast appropriate messages.
      @spectators.each do |spectator|
        begin
          sock.write_bytes(frame)
        rescue Exception
          kill spectator
        end
      end
    end

    # ------------------------
    #
    #
    private
    def kill(sock)

      @spectators.delete(sock)

      begin
        sock.close
        puts "User #{user.name} disconnected."
      rescue Exception

      end
    end
  end
end