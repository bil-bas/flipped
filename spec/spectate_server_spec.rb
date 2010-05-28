require "helper"

require 'book'
require 'spectate_server'
include Flipped

describe SpectateServer do

  before :each do
    @book_dir = File.expand_path(File.join(ROOT, 'test_data', 'flipBooks', '00001'))
    @out_dir = File.expand_path(File.join(ROOT, 'test_data', 'output'))
    @original_book = Book.new(@book_dir)
    @template_dir = File.join(ROOT, 'templates')

    @log = Logger.new(STDOUT)
    @log.progname = "SPEC SpectateServer"
    @server_name = "Test Server"
    @server = described_class.new(described_class::DEFAULT_PORT, @server_name)
  end

  it "should do something" do
    @threads = []
    5.times do |i|
      sleep 0.01
      
      thread = Thread.new(@book_dir) do |book_dir|
        example_book = Book.new(book_dir)
        socket = TCPSocket.new('localhost', SpectateServer::DEFAULT_PORT)

        book = Book.new
        start = Time.now
        message = Message.read(socket)
        message.should be_a_kind_of Message::Challenge
        message.name.should == @server_name
        @log.debug { "Spectator #{i} connected to #{message.name} on #{socket.addr[3]}" }

        Message::Login.new(:name => "Spectator #{i}").write(socket)
        message = Message.read(socket)
        message.should be_a_kind_of Message::Accept
        
        while book.size < example_book.size
          message = Message.read(socket)
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
        socket.close
      end

      @threads.push thread
    end

    sleep 1
    @server.update_spectators(@original_book)

    @threads.each { |t| t.join }
    
    @log.debug { "Closing server" }
    @server.close
  end
end