#!/usr/bin/ruby -w
# encoding: utf-8

begin
  module Flipped
    # Root of executing script files (where .rbw is _actually_ running from).
    EXECUTION_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    # Root relative to .rbw/exe used to start the app, such as contains templates and config.
    INSTALLATION_ROOT = if ENV['OCRA_EXECUTABLE']
      File.expand_path(File.join(File.dirname(ENV['OCRA_EXECUTABLE']), '..'))
    else
      EXECUTION_ROOT
    end
  end

  $LOAD_PATH.unshift File.join(Flipped::EXECUTION_ROOT, 'lib', 'flipped')
  require 'constants'

  # Prevent warnings going to STDERR/STDOUT from killing the rubyw app.
  ORIGINAL_STDERR = $stderr.dup
  $stderr.reopen(Flipped::STDERR_LOG_FILENAME)

  ORIGINAL_STDOUT = $stdout.dup
  $stdout.reopen(Flipped::STDOUT_LOG_FILENAME)
  
  require 'logger'

  log = Logger.new(Flipped::LOG_FILE)
  log.progname = File.basename(__FILE__)

  log.info { "Log created" }

  require 'gui'

  application = Fox::FXApp.new(Flipped::APP_NAME, Flipped::AUTHOR) 
  Flipped::Gui.new(application)
 
  unless defined?(Ocra) # Don't run the app fully if we are compiling the exe.
    log.info { "Starting FXRuby application" }
    application.create 
    application.run
    log.info { "FXRuby application ended" }
  end
 
rescue Exception => ex
  log.fatal { ex }
  
ensure
  $stderr.reopen(ORIGINAL_STDERR) if defined? ORIGINAL_STDERR
  $stdout.reopen(ORIGINAL_STDOUT) if defined? ORIGINAL_STDOUT
  log.info { "Closing log" } if defined? log
  Flipped::LOG_FILE.close if defined? Flipped::LOG_FILE
end
