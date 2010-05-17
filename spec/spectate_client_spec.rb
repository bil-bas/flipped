require "spec"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'flipped'))

require 'spectate_client'
include Flipped

describe SpectateClient do
  before :each do
    @book_dir = File.expand_path(File.join('..', 'test_data', 'flipBooks', '00001'))
    @out_dir = File.expand_path(File.join('..', 'test_data', 'output'))
    @book = Book.new(@book_dir)
    @template_dir = File.join('..', 'templates')

    @log = Logger.new(STDOUT)
    @log.progname = "SPEC SpectateClient"
  end

  it "should do something" do
    server = SpectateServer.new(@book_dir)

    @threads = []
    5.times do |i|
      sleep 0.01
      
      thread = Thread.new(@book_dir) do |book_dir|
        example_book = Book.new(book_dir)
        
        dir = File.join(@out_dir, "Spectator_client_spec_#{i}")
        Dir["#{dir}*"].each do |dir|
          FileUtils.rm_r dir if File.exists? dir
        end

        spectator = described_class.new(dir, @template_dir, 'localhost')

        sleep 3

        spectator.size.should == @book.size

        spectator.close
      end

      @threads.push thread
    end

    @threads.each { |t| t.join }
    
    @log.debug { "Closing server" }
    server.close
  end
end