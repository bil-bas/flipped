#!/usr/bin/ruby -w

REQUIRED_GEMS = %w[fxruby r18n-desktop json]

puts 'Installing/updating required libraries. This could take a minute or two...'
puts

case RUBY_PLATFORM
  when /cygwin|mingw|win32/ # Windoze
    pause = true
    gem = 'gem'
    
    # Win32-Sound only needs to be installed on Windows and would obviously fail elsewhere.
    system "#{gem} install win32-sound --no-ri --no-rdoc"

  when /darwin/  # Mac OS X
    pause = false
    gem = 'sudo gem'
    
  else # Linux or BSD or something crazy.
    # TODO: Distros other than Ubuntu need anything different?
    pause = false
    gem = 'sudo gem1.8'
end

system "#{gem} install #{REQUIRED_GEMS.join(' ')} --no-ri --no-rdoc"
puts

puts 'Library installation complete.'
puts

system 'pause' if pause
