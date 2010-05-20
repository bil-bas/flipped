require 'logger'

begin
  require 'win32/sound'
  WIN32_SOUND_ENABLED = true
rescue
  WIN32_SOUND_ENABLED = false
end

module Flipped
  class Sound
    MIN_INTERVAL = 1 # Minimum interval between sounds.

    @@log = Logger.new(STDOUT)
    @@log.progname = name

    @@last_played = Time.now - MIN_INTERVAL # Last time a sound was played.

    def self.log
      @@log
    end

    APLAY_ENABLED = system "aplay --help 1> /dev/null 2> /dev/null"
    AFPLAY_ENABLED = system "afplay --help 1> /dev/null 2> /dev/null"
    
    def self.play(filename)
      # Prevent sound spam.
      return if (Time.now - @@last_played) < MIN_INTERVAL

      if WIN32_SOUND_ENABLED
        Win32::Sound.play(filename, Win32::Sound::ASYNC)
        log.debug {"Played (using Win32::Sound): #{filename}" }
      elsif APLAY_ENABLED
        system "aplay -N '#{filename}'" # -N is run aynchronously.
        log.debug { "Played (using aplay): #{filename}" }
      elsif AFPLAY_ENABLED
        system "afplay '#{filename}' &" # & to make the command run in background.
        log.debug { "Played (using afplay): #{filename}" }
      else
        log.error { "No sound player for: #{filename}" }
      end
      
      @@last_played = Time.now
    end
  end
end