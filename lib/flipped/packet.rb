require 'base64'
require 'json'

module Flipped
  # Abstract class, parent of all packets.
  class Packet
    JSON_CLASS = 'json_class'

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

    def self.json_create(packet)
      new(packet)
    end

    def ==(other)
      (other.class == self.class) and (other.instance_eval { @values } == @values)
    end
  end

  # Sent by server in response to Join.
  class Challenge < Packet
    value :name, 'Server'
    value :require_password, false
  end

  # Sent by client to server on initial connection.
  class Login < Packet
    value :name, 'Client'
    value :password, ''
  end

  # Sent by server in response to Login.
  class Accept < Packet
    value :game, 'Game'
  end

  # Sent by server in response to Login.
  class Reject < Packet
  end

  # Frame data.
  class Frame < Packet
    value :data, ''

    def frame
      Base64.decode64(@values['data'])
    end

    def initialize(values = {})
      super(:data => values[:frame] ? Base64.encode64(values[:frame]) : values['data'] )
    end
  end

  # Sent by server to tell the client to clear current book.
  class Clear < Packet
  end
end