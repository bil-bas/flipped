require "spec"

ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))

$LOAD_PATH.unshift File.expand_path(File.join(ROOT, 'lib', 'flipped'))

module Flipped
  INSTALLATION_ROOT = EXECUTION_ROOT = ROOT
  LOG_FILE = STDOUT
end