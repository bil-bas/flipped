require 'logger'
require 'zlib'

require 'packet'

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
          length = @socket.read(4)
          length = length.unpack('L')[0]

          packet = @socket.read(length)
          packet = JSON.parse(packet)

          case packet
            when Login
              @name = packet.name
              # TODO: Check password.
              log.info { "#{@socket.addr[3]}:#{@socket.addr[1]} identified as #{@name}." }
              send(Accept.new)
              
            else
              # Ignore.
          end
        rescue Exception
          # Ignore.
        end
      end
    end

    # Send a particular packet.
    def send(packet)      
      return if @socket.closed?
      
      encoded = packet.to_json
      compressed = Zlib::Deflate.deflate(encoded)
      log.info { "Sending #{packet.class} (#{encoded.size} => #{compressed.size} bytes)" }
      log.debug { encoded }
      @socket.write([compressed.size].pack('L'))
      @socket.write(compressed)
      @socket.flush

      # If a frame is being sent, then increment our own position.
      case packet
        when Packet::Frame
          @position += 1

        when Packet::Clear
          @position = INITIAL_POSITION
      end

      encoded.size
    end
  end
end