require 'logger'

require 'message'

 module Flipped
   class Spectator
    INITIAL_POSITION = -1

    attr_reader :socket, :id
    attr_accessor :position, :name

    @@next_spectator_id = 1

    @@log = Logger.new(STDOUT)
    @@log.progname = name

    def log
      @@log
    end

    def initialize(owner, socket)
      @owner, @socket = owner, socket

      @name = nil
      @position = INITIAL_POSITION
      @id = @@next_spectator_id
      @@next_spectator_id += 1

      Thread.new do
        begin
          message = Message.read(@socket)
          case message
            when Message::Login
              @name = message.name
              # TODO: Check password.
              log.info { "#{@socket.addr[3]}:#{@socket.addr[1]} identified as #{@name}." }
              send(Message::Accept.new)
              
            else
              # Ignore.
          end
        rescue Exception => ex
          log.error { "#{@name} died unexpectedly while reading (#{ex})" }
          @socket.close unless @socket.closed?
        end
      end
    end

    # Send a particular packet.
    def send(message)
      return if @socket.closed?
      begin
        size = message.write(@socket)
      rescue => ex
        log.error { "#{@name} died unexpectedly while writing (#{ex})" }
        @socket.close unless @socket.closed?
      end

      # If a frame is being sent, then increment our own position.
      case message
        when Message::Frame
          @position += 1

        when Message::Clear
          @position = INITIAL_POSITION
      end

      size
    end
  end
end