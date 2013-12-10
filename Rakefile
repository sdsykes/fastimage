require 'rake/testtask'

#require 'bundler'
#Bundler::GemHelper.install_tasks

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test.rb']
  t.verbose = true
end

task :default => :test
