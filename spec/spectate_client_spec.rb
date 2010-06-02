require "helper"

require 'book'
require 'spectate_client'
include Flipped

describe SpectateClient do
  before :each do
    @book_dir = File.expand_path(File.join(ROOT, 'test_data', 'sid_with_flip_books', 'flipBooks', '00001'))
    @out_dir = File.expand_path(File.join(ROOT, 'test_data', 'output'))
    @book = Book.new(@book_dir)
    @template_dir = File.join(ROOT, 'templates')

    @log = Logger.new(STDOUT)
    @log.progname = "SPEC SpectateClient"

    @player_name = "Test Server"
    @server = SpectateServer.new(SpectateServer::DEFAULT_PORT, true)
  end

  after :each do
    @server.close
  end

  it "should do something" do
    player = described_class.new('localhost', SpectateServer::DEFAULT_PORT, "Player client", :player, 60)
    sleep 0.2
    player.send_frames(@book.frames)

    @threads = []
    5.times do |i|
      sleep 0.01
      
      thread = Thread.new(@book_dir) do |book_dir|
        example_book = Book.new(book_dir)
        
        dir = File.join(@out_dir, "Spectator_client_spec_#{i}")
        Dir["#{dir}*"].each do |dir|
          FileUtils.rm_r dir if File.exists? dir
        end

        spectator = described_class.new('localhost', SpectateServer::DEFAULT_PORT, "Spectator client #{i}", :spectator, nil)

        sleep 3
        
        frames = spectator.frames_buffer
        frames.size.should == @book.size
        frames.should == @book.frames

        spectator.close
      end

      @threads.push thread
    end

    sleep 1

    @threads.each { |t| t.join }
    
    @log.debug { "Closing server" }
    @server.close
  end
end