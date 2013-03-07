Gem::Specification.new do |s|
  s.name = %q{fastimage}
  s.version = "1.2.14"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Stephen Sykes"]
  s.date = %q{2013-03-07}
  s.description = %q{FastImage finds the size or type of an image given its uri by fetching as little as needed.}
  s.email = %q{sdsykes@gmail.com}
  s.extra_rdoc_files = [
    "README",
     "README.textile"
  ]
  s.files = [
    "README",
     "README.textile",
     "lib/fastimage.rb",
     "test/fixtures/faulty.jpg",
     "test/fixtures/test.bmp",
     "test/fixtures/test.gif",
     "test/fixtures/test.ico",
     "test/fixtures/test.jpg",
     "test/fixtures/test.png",
     "test/fixtures/test2.jpg",
     "test/fixtures/test3.jpg",
     "test/fixtures/folder with spaces/test.bmp",
     "test/test.rb"
  ]
  s.homepage = %q{http://github.com/sdsykes/fastimage}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{FastImage - Image info fast}
  s.test_files = [
    "test/test.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

