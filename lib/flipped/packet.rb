module Flipped
  module Packet
    # Tags existing within packets.
    module Tag
      TYPE = 'type' # Type of the packet (one of Packet::Type)
      NAME = 'name' # Name of the client/server.
      DATA = 'data' # Base64 encoded png.
    end

    # Types of packet being sent.
    module Type
      FRAME = 'frame' # A frame (Tag::DATA)
      CLIENT_INIT = 'client' # An init from a client (Tag::NAME)
      SERVER_INIT = 'server' # An init from the server (Tag::NAME)
    end
  end
end