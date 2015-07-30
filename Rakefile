require 'bundler/setup'
require "bundler/gem_tasks"
Bundler.require(:development)

require 'fileutils'
require "rake/testtask"

# Test Task
Rake::TestTask.new do |t|
    t.libs << 'lib' << 'test'
    t.test_files = FileList['test/**/*_test.rb']
    # t.warning = true
    # t.verbose = true
end

# require "sdoc"
# RDoc::Task.new do |rdoc|
#   rdoc.main = 'README.md'
#   rdoc.title = 'Wankel API'
#   rdoc.rdoc_dir = 'doc'
#
#   rdoc.rdoc_files.include('README.md')
#   rdoc.rdoc_files.include('logo.png')
#   rdoc.rdoc_files.include('lib/**/*.rb')
#   rdoc.rdoc_files.include('ext/**/*.{h,c}')
#
#   rdoc.options << '-f' << 'sdoc'
#   rdoc.options << '-T' << '42floors'
#   rdoc.options << '--charset' << 'utf-8'
#   rdoc.options << '--line-numbers'
#   rdoc.options << '--github'
# end