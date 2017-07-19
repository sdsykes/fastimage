require "rdoc/task"
require "rake/testtask"
require "rubocop/rake_task" if RUBY_VERSION >= "2.1.0"

# Generate documentation
Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("*.rdoc", "lib/**/*.rb")
  rd.rdoc_dir = "rdoc"
end

# require 'bundler'
# Bundler::GemHelper.install_tasks

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/test.rb"]
  t.verbose = true
end

if RUBY_VERSION >= "2.1.0"
  RuboCop::RakeTask.new

  task default: %w[test rubocop]
else
  task default: "test"
end
