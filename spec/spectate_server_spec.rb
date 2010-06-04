require "helper"

require 'book'
require 'spectate_server'
include Flipped

describe SpectateServer do

  before :each do
    @book_dir = File.expand_path(File.join(ROOT, 'test_data', 'sid_with_flip_books', 'flipBooks', '00001'))
    @out_dir = File.expand_path(File.join(ROOT, 'test_data', 'output'))
    @original_book = Book.new(@book_dir)
    @template_dir = File.join(ROOT, 'templates')

    @log = Logger.new(STDOUT)
    @log.progname = "SPEC SpectateServer"
    @player_name = "Test Server"
    @server = described_class.new(described_class::DEFAULT_PORT)
  end

  after :each do
    @server.close
  end

  # Run through the process of logging in a player client socket.
  def login(name, role, time_limit = nil)
    socket = TCPSocket.new('localhost', SpectateServer::DEFAULT_PORT)

    message = Message.read(socket)
    message.should be_a_kind_of Message::Challenge

    Message::Login.new(:name => name, :time_limit => time_limit, :role => role).write(socket)
    message = Message.read(socket)
    message.should be_a_kind_of Message::Accept

    message = Message.read(socket)
    message.should be_a_kind_of Message::Connected
    message.id.should >= 1
    message.name.should == name
    message.role.should == role
    message.time_limit.should == time_limit

    socket
  end

  it "should accept a player login" do
    login('player', :player, 60)
  end

  it "should accept frames sent by a player" do
    player_socket = login('player', :player, 60)
    @original_frame_messages = Array.new
    @original_book.frames.each do |frame|
      message = Message::Frame.new(:frame => frame)
      @original_frame_messages.push message
      message.write(player_socket)
    end

    sleep 0.1
    @server.instance_variable_get('@frames').should == @original_frame_messages
  end

  it "should send frames to multiple spectators" do
    # Create a dummy player and send the book to the server.
    player_socket = login('player', :player, 60)
    @original_book.frames.each do |frame|
      Message::Frame.new(:frame => frame).write(player_socket)
    end

    @threads = []
    5.times do |i|
      sleep 0.01
      
      thread = Thread.new(@book_dir) do |book_dir|
        example_book = Book.new(book_dir)
        
        book = Book.new
        start = Time.now

        spectator = login("Spectator #{i}", :spectator)

        # Should get updated with teh whole book.
        while book.size < example_book.size
          message = Message.read(spectator)
          next if message.is_a? Message::Connected # Ignore for now. No way to know how many we'll get due to race state.

          message.should be_a_kind_of Message::Frame
          book.insert(book.size, message.frame)

          book[book.size - 1].length.should == example_book[book.size - 1].length
          book[book.size - 1].should == example_book[book.size - 1]
        end

        book.size.should == example_book.size

        dir = File.join(@out_dir, "Spectator_server_spec #{i}")
        FileUtils.rm_r dir if File.exists? dir
        book.write(dir, @template_dir)

        @log.debug { "Spectator_server_spec #{i} took #{Time.now - start} to read #{book.size} frames." }
        spectator.close
      end

      @threads.push thread
    end

    sleep 1

    @threads.each { |t| t.join }
    player_socket.close
  end
end