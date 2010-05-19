require 'logger'

require 'packet'

 module Flipped
   class Spectator
    include Packet

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
      @position = -1
      @id = @@next_spectator_id
      @@next_spectator_id += 1

      Thread.new do
        begin
          length = @socket.read(4)
          length = length.unpack('L')[0]

          packet = @socket.read(length)
          packet = JSON.parse(packet)

          case packet[Tag::TYPE]
            when Type::CLIENT_INIT
              @name = packet[Tag::NAME]
              log.info { "#{@socket.addr[3]}:#{@socket.addr[1]} identified as #{@name}." }

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
      @socket.write([encoded.size].pack('L'))
      @socket.write(encoded)
      @socket.flush

      # If a frame is being sent, then increment our own position.
      @position += 1 if packet[Tag::TYPE] == Type::FRAME

      encoded.size
    end
  end
end