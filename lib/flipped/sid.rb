module Flipped
  class SiD
    SETTINGS_EXTENSION = '.ini'

    EXECUTABLE = (RUBY_PLATFORM =~ /cygwin|win32|mingw/) ? 'SleepIsDeath.exe' : 'SleepIsDeathApp'

    SETTINGS = {
      :auto_host => :boolean,
      :auto_join => :boolean,
      :default_server_address => :string,
      :flip_book => :boolean,
      :fullscreen => :boolean,
      :hard_to_quit_mode => :boolean,
      :port => :integer,
      :screen_height => :integer,
      :screen_width => :integer,
      :time_limit => :integer,
    }

    SETTINGS.each_pair do |setting, type|
      class_eval(<<EOS, __FILE__, __LINE__)
        def #{setting}#{type == :boolean ? '?' : ''}
          @settings[:#{setting}]
        end

        def #{setting}=(value)
          @settings[:#{setting}] = value
        end
EOS
    end
    
    def executable
      File.join(@root, EXECUTABLE)
    end
    
    def initialize(root_directory)
      @root = root_directory
      @thread = nil
      read_settings
    end

    def read_settings
      @settings = Hash.new
      SETTINGS.each_pair do |setting, type|
        value = File.read(File.join(settings_folder, "#{symbol_to_string setting}.ini")).strip
        @settings[setting] = case type
          when :integer
            value.to_i
          when :boolean
            value == "0" ? false : true
          else
            value
        end
      end

      nil
    end

    def write_settings
      SETTINGS.each_pair do |setting, type|
        File.open(File.join(settings_folder, "#{symbol_to_string setting}#{SETTINGS_EXTENSION}"), "w") do |file|
          value = case type
            when :boolean
              @settings[setting] ? "1" : "0"
            else
              @settings[setting].to_s
          end
          file.puts(value)
        end
      end

      nil
    end

    def run
      write_settings
      
      @thread = Thread.new do
        system executable
      end

      nil
    end

    def kill
      @thread.kill if @thread
    end

  protected
    def settings_folder
      File.join(@root, 'settings')
    end

    # Convert a symbolic to string name.
    def symbol_to_string(str)
      str.to_s.gsub(/(_[a-z])/) { |c| c[1..1].upcase }
    end
  end
end