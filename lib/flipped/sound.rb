require 'log'

begin
  gem 'win32-sound'
  require 'win32/sound'
  WIN32_SOUND_ENABLED = true
rescue LoadError
  WIN32_SOUND_ENABLED = false
end

module Flipped
  class Sound
    include Log

    MIN_INTERVAL = 1 # Minimum interval between sounds.

    @@last_played = Time.now - MIN_INTERVAL # Last time a sound was played.

    if WIN32_SOUND_ENABLED
      log.info { "Using Win32-sound"} if WIN32_SOUND_ENABLED
      APLAY_ENABLED = false
      AFPLAY_ENABLED = false
    else
      if RUBY_PLATFORM =~ /darwin/ # OS X
        AFPLAY_ENABLED = system "afplay --help 1> /dev/null 2> /dev/null"
        log.info { "Using OS X afplay"} if AFPLAY_ENABLED
        APLAY_ENABLED = false
      else # Linux or some such.
        APLAY_ENABLED = system "aplay --help 1> /dev/null 2> /dev/null"
        log.info { "Using *NIX aplay"} if APLAY_ENABLED
        AFPLAY_ENABLED = false
      end
    end

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