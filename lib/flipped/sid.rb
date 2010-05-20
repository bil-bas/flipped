module Flipped
  class SiD
    SETTINGS_EXTENSION = '.ini'
    attr_accessor :executable

    def root
      File.dirname(@executable)
    end

    def []=(key, value)
      raise Exception.new("No settings for #{key}") unless @settings.has_key? key
      @settings[key] = value
    end

    def [](key)
      raise Exception.new("No settings for #{key}") unless @settings.has_key? key
      @settings[key]
    end
    
    def initialize(executable)
      @executable = executable
      read_settings
    end

    def read_settings
      @settings = Hash.new
      Dir(File.join(settings_folder, "*.ini")).each do |filename|
        @settings[File.basename(filename).sub(SETTINGS_EXTENSION, '')] = File.read(filename)
      end
    end

    def write_settings
      @settings.each_pair do |key, value|
        File.open(File.join(settings_folder, "#{key}#{SETTINGS_EXTENSION}")) do |file|
          file.print(value)
        end
      end
    end

    def run
      write_settings
      system @executable

    end

  protected
    def settings_folder
      File.join(root, 'settings')
    end
  end
end