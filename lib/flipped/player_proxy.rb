require 'socket'
require 'thread'

require 'log'
require 'sid_proxy'

module Flipped
  # Allows a game of SiD to be hosted elsewhere than on the controller's machine.
  # This is connected to from directly from the player and also from the ControllerProxy.
  class PlayerProxy < SiDProxy
    include Log
    
    def initialize(player_port, controller_proxy_port)
      Thread.new do
        player_accept_thread = Thread.new do
          @player = accept(player_port)
        end
        @controller_proxy = accept(controller_proxy_port)
        
        join player_accept_thread

        redirect(@player, @controller_proxy)
        redirect(@controller_proxy, @player)
      end

      nil
    end

  protected
    # Accept a connection.
    def accept(port)
      server = TCPServer.new(port)
      
      socket = server.accept
      log.info { "Accepted connection from #{socket.addr[3]}:#{port}" }

      server.close
      
      socket
    end
  end
end
