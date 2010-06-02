require 'socket'
require 'thread'

require 'log'
require 'sid_proxy'

module Flipped
  # Allows a game of SiD to be hosted elsewhere than on the controller's machine.
  # This connects to both the PlayerProxy and the controller.
  class ControllerProxy < SiDProxy
    include Log
    
    def initialize(controller_port, player_proxy_address, player_proxy_port)
      Thread.new do
        @player_proxy = connect(player_proxy_address, player_proxy_port)
        @controller = connect('localhost', controller_port)

        redirect(@player_proxy, @controller)
        redirect(@controller, @player_proxy)
      end

      nil
    end

  protected
    # Connect to the local controller.
    def connect(address, port)
      socket = nil
      until socket
        begin
          socket = TCPSocket.new(address, port)
        rescue Errno::ECONNREFUSED
        end
      end
      log.info { "Connected to #{address}:#{port}" }

      socket
    end
  end
end
