$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'flipped'))

require 'gui'
include Flipped

application = FXApp.new(Gui::APPLICATION)

window = Gui.new(application)

# Handle interrupts to terminate program gracefully
application.addSignal("SIGINT", window.method(:on_cmd_quit))

application.create
application.run