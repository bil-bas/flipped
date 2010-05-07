$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'flipped'))

require 'gui'
include Flipped

sid_dir = File.expand_path(File.join(__FILE__, '..', '..'))
book_dir = File.join(sid_dir, 'flipBooks')
templates_dir = File.join(sid_dir, 'templates')

# TODO: Make a simple CLI app:
# --version -v         Prints this message.
# --sid -s       PATH  SiD directory (defaults to '..')
# --in -i        A,B,C List of flip-books to load in, such as '00001,00003'. Read from 'SID\flipBooks\'
# --templates -t DIR   Flip-book templates to use (defaults to 'SID\templates')
# --out -o       DIR   New flipbook to write out (defaults to 'SID\flipBooks\A + B + C')
# --delete -d    N,M,P Indexes of frames to delete (such as '3,4,5,7,22,9').
# --resize -r    W     Width of new images in flipbook (such as '640' to get standard 640x416 images)

AUTHOR = 'Spooner aka Bil Bas'
application = FXApp.new(Gui::APPLICATION)

window = Gui.new(application)

# Handle interrupts to terminate program gracefully
application.addSignal("SIGINT", window.method(:on_cmd_quit))

application.create
application.run