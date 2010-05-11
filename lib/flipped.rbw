#!/usr/bin/env ruby -w

begin

  $LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'flipped'))

  require 'gui'
  include Flipped

  application = FXApp.new(Gui::APPLICATION)

  window = Gui.new(application)

  # Handle interrupts to terminate program gracefully
  application.addSignal("SIGINT", window.method(:on_cmd_quit))

  unless defined?(Ocra)
    application.create 
    application.run
  end
rescue Exception => e
  # Log any uncaught exceptions.
  File.open("error.log", 'w') do |f|
    f.puts "#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
  end
end
