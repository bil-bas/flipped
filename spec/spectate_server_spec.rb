require "spec"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'flipped'))

require 'spectate_server'
include Flipped



describe SpectateServer do

  before :each do
    @book_dir = File.expand_path(File.join('..', 'test_data', 'flipBooks', '00001'))
    @out_dir = File.expand_path(File.join('..', 'test_data', 'output'))
    @book = Book.new(@book_dir)
    @template_dir = File.join('..', 'templates')

    @log = Logger.new(STDOUT)
    @log.progname = "SPEC SpectateServer"
  end

  it "should do something" do

    server = described_class.new(@book_dir)

    @threads = []
    5.times do |i|
      sleep 0.01
      
      thread = Thread.new(@book_dir) do |book_dir|
        example_book = Book.new(book_dir)
        spectator = TCPSocket.new('localhost', SpectateServer::DEFAULT_PORT)
        spectator.puts("Spectator #{i}")
        
        book = Book.new
        start = Time.now
        @log.debug { "Spectator #{i} connected to #{spectator.gets.strip} on #{spectator.addr[3]}" }
        while length = spectator.read(4)
          length = length.unpack('L')[0]
          buffer = ''
          while buffer.length < length
            buffer += spectator.read(length - buffer.size)
          end
          book.insert(book.size, buffer)

          book[book.size - 1].size.should == example_book[book.size - 1].size
          book[book.size - 1].should == example_book[book.size - 1]

          break if book.size == example_book.size
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

    @threads.each { |t| t.join }
    
    @log.debug { "Closing server" }
    server.close
  end
end