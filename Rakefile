require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "fastimage"
    s.summary = "FastImage - Image info fast"
    s.email = "sdsykes@gmail.com"
    s.homepage = "http://github.com/sdsykes/fastimage"
    s.description = "FastImage finds the size or type of an image given its uri by fetching as little as needed."
    s.authors = ["Stephen Sykes"]
    s.files = FileList["[A-Z]*", "{lib,test}/**/*"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://
gems.github.com"
end
