require 'base64'
require 'json'
require 'zlib'

require 'log'

module Flipped
  # Abstract class, parent of all packets.
  class Message
    include Log
    
    JSON_CLASS = 'json_class'
    LENGTH_FORMAT = 'N' # 32-bit int, network order.
    LENGTH_FORMAT_SIZE = 4 # 32-bit int

    # Class => {name => default, name => default, ...]
    @@value_defaults = Hash.new { |hash, key| hash[key] = {} }

    # Values are stored internally keyed by strings, but for the user they are symbols.
    def self.value(symbol, default)
      @@value_defaults[self][symbol] = default

      class_eval(<<-EOS, __FILE__, __LINE__)
        def #{symbol}#{[true, false].include?(default) ? '?' : ''}
          @values['#{symbol}'] || @@value_defaults[self.class][:#{symbol}]
        end
      EOS
    end

    def initialize(values = {})
      @values = Hash.new
      @@value_defaults[self.class].each_pair do |symbol, default|
        key = if values.has_key? JSON_CLASS
          symbol.to_s # Being re-constructed from a stream.
        else         
          symbol # Being initially created.
        end
        @values[symbol.to_s] = values[key] unless values[key] == default or values[key].nil?
      end
    end

    def to_json(*args)
      @values.merge(JSON_CLASS => self.class.name).to_json(*args)
    end

    def self.json_create(message)
      new(message)
    end

    # Read the next message from a stream.
    #
    # === Parameters
    # +io+:: Stream from which to read a message.
    #
    # Returns message read [Message]
    def self.read(io)
      length = io.read(LENGTH_FORMAT_SIZE)
      raise IOError.new("Failed to read message length") unless length
      length = length.unpack(LENGTH_FORMAT)[0]

      body = io.read(length)
      raise IOError.new("Failed to read message body") unless body

      JSON.parse(Zlib::Inflate.inflate(body))      
    end

    # Write the message onto a stream.
    #
    # === Parameters
    # +io+:: Stream on which to write self.
    #
    # Returns the number of bytes written (not including the size header).
    def write(io)
      encoded = to_json
      compressed = Zlib::Deflate.deflate(encoded)
      log.info { "Sending #{self.class} (#{encoded.size} => #{compressed.size} bytes)" }
      log.debug { encoded }
      io.write([compressed.size].pack(LENGTH_FORMAT))
      io.write(compressed)

      compressed.size
    end

    def ==(other)
      (other.class == self.class) and (other.instance_eval { @values } == @values)
    end

    # Sent by server in response to making a connection.
    class Challenge < Message
      include Log
      
      value :name, 'Server'
      value :require_password, false
    end

    # Sent by client to server in response to Challenge.
    class Login < Message
      include Log

      value :name, 'Client'
      value :password, ''
    end

    # Sent by server in response to Login.
    class Accept < Message
      include Log
    end

    # Sent by server in response to Login.
    class Reject < Message
      include Log
    end

    # Frame data.
    class Frame < Message
      include Log

      value :data, ''

      def frame
        Base64.decode64(@values['data'])
      end

      def initialize(values = {})
        super(:data => values[:frame] ? Base64.encode64(values[:frame]) : values['data'] )
      end
    end

    # Sent by server to tell the client to clear current book ready for a new story.
    class Story < Message
      include Log

      value :name, 'Story'
    end
  end
end