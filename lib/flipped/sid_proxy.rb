require 'socket'
require 'thread'

require 'log'

module Flipped
  # Allows a game of SiD to be hosted elsewhere than on the controller's machine. 
  class SiDProxy
    include Log

  protected
    def redirect(from, to)
      Thread.new do
        begin
          until from.closed? or to.closed?
            # The SiD message header is 6 bytes:
            #   0: channel (whatever that is)
            #   1-4: message size (Network byte-order)
            #   5: checksum (completely unnecessary, surely?)
            header = from.read(6)
            channel, size, checksum = header.unpack('CNC')
            body = from.read(size)

            log.debug { "Redirecting #{size} byte message" }

            to.write(header)
            to.write(body)
          end
        rescue Exception => ex
          log.error { "Redirection failed: #{from} => #{to}" }
          log.error { ex }
          from.close unless from.closed?
          to.close unless to.closed?
        end
      end
    end
  end
end
