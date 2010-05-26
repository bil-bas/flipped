require 'base64'
require 'json'
require 'zlib'
require 'logger'

module Flipped
  # Abstract class, parent of all packets.
  class Message
    JSON_CLASS = 'json_class'
    LENGTH_FORMAT = 'L'

    @@log = Logger.new(STDOUT)
    @@log.progname = name
    
    def log
      @@log
    end

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
      @values = {}
      @@value_defaults[self.class].each_pair do |sym, default|
        @values[sym.to_s] = values[sym] unless values[sym] == default or values[sym].nil?
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
      length = io.read(4)
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

    # Sent by server in response to Join.
    class Challenge < Message
      value :name, 'Server'
      value :require_password, false
    end

    # Sent by client to server on initial connection.
    class Login < Message
      value :name, 'Client'
      value :password, ''
    end

    # Sent by server in response to Login.
    class Accept < Message
      value :game, 'Game'
    end

    # Sent by server in response to Login.
    class Reject < Message
    end

    # Frame data.
    class Frame < Message
      value :data, ''

      def frame
        Base64.decode64(@values['data'])
      end

      def initialize(values = {})
        super(:data => values[:frame] ? Base64.encode64(values[:frame]) : values['data'] )
      end
    end

    # Sent by server to tell the client to clear current book.
    class Clear < Message
    end
  end
end