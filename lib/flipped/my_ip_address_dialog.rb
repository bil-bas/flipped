require 'net/http'
require 'uri'
require 'fox16'
include Fox

require 'dialog'
require 'log'

module Flipped
  class MyIPAddressDialog < Dialog
    include Log

    #IP_ADDRESS_PAGE = URI.parse('http://www.whatismyip.org/')
    IP_ADDRESS_PAGE = URI.parse('http://checkip.dyndns.org/')
    
    protected
    def initialize(owner, t)
      super(owner, t.title, t.accept_button)

      @initial_address = t.ip_address.initial

      FXLabel.new(@grid, t.ip_address.label)
      @address_field = FXTextField.new(@grid, 15) do |widget|
        widget.editable = false
        widget.text = @initial_address
      end

      skip_grid
      skip_grid

      @message = FXLabel.new(@grid, '')

      nil
    end

    def create(*args)
      super
      update_address
    end

    protected
    def update_address
      Thread.abort_on_exception = true
      Thread.new do
        log.info { "Fetching IP address from #{IP_ADDRESS_PAGE}" }
        @address_field.text = @initial_address
        begin
          response = Net::HTTP.get(IP_ADDRESS_PAGE)
          if response =~ /(\d+\.\d+\.\d+\.\d+)/
            log.info { "IP address found to be #{$1}"}
            @address_field.text = $1
            @message.text = ''
          else
            log.error { "IP address not found at #{IP_ADDRESS_PAGE} (received: #{response})." }
            @address_field.text = @initial_address
            @message.text = "Failed, try again in a few seconds."
          end
        rescue Exception => ex
          @address_field.text = @initial_address
          log.error { ex }
        end
      end
    end
  end
end