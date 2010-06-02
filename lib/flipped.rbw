#!/usr/bin/ruby -w
# encoding: utf-8

module Flipped
  # Root of executing script files (where .rbw is _actually_ running from).
  EXECUTION_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Root relative to .rbw/exe used to start the app, such as contains templates and config.
  INSTALLATION_ROOT = if ENV['OCRA_EXECUTABLE']
    File.expand_path(File.join(File.dirname(ENV['OCRA_EXECUTABLE']), '..'))
  else
    EXECUTION_ROOT
  end

  LOG_DIR = File.join(INSTALLATION_ROOT, 'logs')
  Dir.mkdir Flipped::LOG_DIR unless File.exists? Flipped::LOG_DIR
  LOG_FILENAME = File.join(LOG_DIR, 'flipped.log')
  LOG_FILE = File.open(LOG_FILENAME, 'w')
  LOG_FILE.sync = true
end

begin
  # Prevent warnings going to STDERR from killing the rubyw app.
  ORIGINAL_STDERR = $stderr.dup
  $stderr.reopen(File.join(Flipped::LOG_DIR, 'stderr.log'))

  ORIGINAL_STDOUT = $stdout.dup
  $stdout.reopen(File.join(Flipped::LOG_DIR, 'stdout.log'))

  require 'logger'

  log = Logger.new(Flipped::LOG_FILE)
  log.progname = File.basename(__FILE__)

  log.info { "Log created" }
  
  $LOAD_PATH.unshift File.join(Flipped::EXECUTION_ROOT, 'lib', 'flipped')
  require 'gui'
  
  application = Fox::FXApp.new('Flipped', 'Spooner')
  window = Flipped::Gui.new(application)

  # Handle interrupts to terminate program gracefully
  application.addSignal("SIGINT", window.method(:on_cmd_quit))
 
  unless defined?(Ocra) # Don't run the app fully if we are compiling the exe.
    log.info { "Starting FXRuby application" }
    application.create 
    application.run
    log.info { "FXRuby application ended" }
  end
 
rescue Exception => ex
  log.fatal { ex }
  
ensure
  $stderr.reopen(ORIGINAL_STDERR)
  $stdout.reopen(ORIGINAL_STDOUT)
  log.info { "Closing log" }
  Flipped::LOG_FILE.close
end
