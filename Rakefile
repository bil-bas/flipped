require 'rake/rdoctask'
require 'spec/rake/spectask'
require 'rake/clean'
require 'fileutils'
include FileUtils

RDOC_DIR = './doc/rdoc'

CLOBBER.include FileList[RDOC_DIR]

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = RDOC_DIR
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.add(%w(*.rdoc lib/**/*.rb))
  rdoc.title = 'Flipped - The flip-book tool'
end

Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
end