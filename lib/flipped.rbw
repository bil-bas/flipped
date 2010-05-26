#!/usr/bin/ruby -w
# encoding: utf-8

begin
  # Root of executing script files (where .rbw is _actually_ running from).
  EXECUTION_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Root relative to .rbw/exe used to start the app, such as contains templates and config.
  INSTALLATION_ROOT = if ENV['OCRA_EXECUTABLE']
    File.expand_path(File.join(File.dirname(ENV['OCRA_EXECUTABLE']), '..'))
  else
    EXECUTION_ROOT
  end

  LOG_DIR = File.join(INSTALLATION_ROOT, 'logs')
  Dir.mkdir LOG_DIR unless File.exists? LOG_DIR

  LOG_FILENAME = File.join(LOG_DIR, 'flipped.log')
  LOG_FILE = File.open(LOG_FILENAME, 'w')
  LOG_FILE.sync = true

  $LOAD_PATH.unshift File.join(EXECUTION_ROOT, 'lib', 'flipped')

  require 'gui'
  include Flipped

  application = FXApp.new('Flipped', 'Spooner')

  window = Gui.new(application)

  # Handle interrupts to terminate program gracefully
  application.addSignal("SIGINT", window.method(:on_cmd_quit))
 
  unless defined?(Ocra) # Don't run the app fully if we are compiling the exe.
    application.create 
    application.run
  end
rescue Exception => e
  # Log any uncaught exceptions.
  error = "[#{Time.now}]\n#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
  puts error 
  LOG_FILE.puts error
  LOG_FILE.close
end
