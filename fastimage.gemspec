Gem::Specification.new do |s|
  s.name = %q{fastimage}
  s.version = "1.6.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Stephen Sykes"]
  s.date = %q{2014-10-24}
  s.description = %q{FastImage finds the size or type of an image given its uri by fetching as little as needed.}
  s.email = %q{sdsykes@gmail.com}
  s.extra_rdoc_files = [
    "README.textile"
  ]
  s.files = [
    "MIT-LICENSE",
    "README.textile",
    "lib/fastimage.rb",
    "lib/fastimage/fbr.rb",
    "test/fixtures/faulty.jpg",
    "test/fixtures/test.bmp",
    "test/fixtures/test2.bmp",
    "test/fixtures/test.gif",
    "test/fixtures/test.jpg",
    "test/fixtures/test.png",
    "test/fixtures/test2.jpg",
    "test/fixtures/test3.jpg",
    "test/fixtures/test4.jpg",
    "test/fixtures/test.tiff",
    "test/fixtures/test2.tiff",
    "test/fixtures/exif_orientation.jpg",
    "test/fixtures/infinite.jpg",
    "test/fixtures/orient_2.jpg",
    "test/fixtures/folder with spaces/test.bmp",
    "test/test.rb",
    "test/fixtures/test.psd",
    "test/fixtures/bad.jpg",
    "test/fixtures/man.ico",
    "test/fixtures/test.cur"
  ]
  s.homepage = %q{http://github.com/sdsykes/fastimage}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{FastImage - Image info fast}
  s.add_runtime_dependency 'addressable', '~> 2.3', '>= 2.3.5'
  s.add_development_dependency 'fakeweb', '~> 1.3'
  s.add_development_dependency(%q<rake>, [">= 0"])
  s.add_development_dependency(%q<rdoc>, [">= 0"])  

  s.test_files = [
    "test/test.rb"
  ]
  s.licenses = ['MIT']
end
