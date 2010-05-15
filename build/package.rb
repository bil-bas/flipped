require 'rake'

# Requires APP_EXE and RELEASE_DIR to be defined before it is required.
	
namespace :build do	
  FOLDERS =	
  [	
    '.idea',
    'bin',	
    'build',	
    'doc',	
    'lib',
    'media',	
	'spec',
	'templates',
    'test_data',
  ]
	
  FILES =	
  [	
    'COPYING.txt',	
    'Rakefile',	
    'README.rdoc',	
  ]	
  
  desc 'Package files'	
  task :package => RELEASE_DIR	
  dependencies = ["compile:#{APP}", 'rdoc:rdoc'].map { |t| Rake::Task[t] }
  file RELEASE_DIR => dependencies do	
    require 'find'
	
    rmtree RELEASE_DIR
	
    makedirs RELEASE_DIR	
    FOLDERS.each do |dir|	
      cp_r "#{dir}", RELEASE_DIR	
    end

    mkdir_p File.join(RELEASE_DIR, 'config')
    cp_r File.join('config', 'locales'), File.join(RELEASE_DIR, 'config')

	
    FILES.each do |file|	
      cp "#{file}", RELEASE_DIR	
    end
	
    # Remove .git crud.	
    Find.find(RELEASE_DIR) do |path|	
      if File.basename(path) == /\.git/
        rmtree path	
        Find.prune	
      end	
    end	
  end	
end