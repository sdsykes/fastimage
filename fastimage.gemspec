require_relative "lib/fastimage/version"

Gem::Specification.new do |s|
  s.name = %q{fastimage}
  s.version = FastImage::VERSION

  s.required_ruby_version = '>= 1.9.2'
  s.authors = ["Stephen Sykes"]
  s.description = %q{FastImage finds the size or type of an image given its uri by fetching as little as needed.}
  s.email = %q{sdsykes@gmail.com}
  s.extra_rdoc_files = [
    "README.md"
  ]
  s.files = [
    "MIT-LICENSE",
    "README.md",
    "lib/fastimage.rb",
    "lib/fastimage/version.rb",
  ]
  s.homepage = %q{http://github.com/sdsykes/fastimage}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{FastImage - Image info fast}
  s.add_dependency 'base64'
  s.add_development_dependency 'fakeweb-fi', '~> 1.3'
  # Note rake 11 drops support for ruby 1.9.2
  s.add_development_dependency('rake', ">= 10.5")
  s.add_development_dependency('rdoc')
  s.add_development_dependency('test-unit')

  s.licenses = ['MIT']
end
