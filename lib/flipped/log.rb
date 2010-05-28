require 'logger'

module Flipped
  module Log
    def self.included(base)
      # Use class variables to store log objects for every class.
      base.class_eval do
        class << self
          attr_accessor :log
        end
      end

      base.log = Logger.new(LOG_FILE)
      base.log.progname = base.name
      base.log.info { "Creating log" }
    end

    attr_reader :log
    def log # :nodoc:
      self.class.log
    end
  end
end