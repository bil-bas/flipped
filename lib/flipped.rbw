#!/usr/bin/ruby1.9.1 -w
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

  $LOAD_PATH.unshift File.join(EXECUTION_ROOT, 'lib', 'flipped')

  require 'gui'
  include Flipped

  application = FXApp.new('Flipped', 'Spooner')

  application.disableThreads # Just makes things run a tiny bit faster, since we aren't using Ruby threads.

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
  File.open(File.join(LOG_DIR, 'error.log'), 'w') do |f|
    f.puts error
  end
end
