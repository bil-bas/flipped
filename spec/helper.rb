require "spec"

ROOT = File.join(File.dirname(__FILE__), '..')
LOG_FILE = STDOUT

$LOAD_PATH.unshift File.expand_path(File.join(ROOT, 'lib', 'flipped'))