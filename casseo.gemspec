require "./lib/casseo/version"

Gem::Specification.new do |gem|
  gem.name        = "casseo"
  gem.version     = Casseo::VERSION

  gem.author      = "Brandur"
  gem.email       = "brandur@mutelight.org"
  gem.homepage    = "https://github.com/brandur/casseo"
  gem.license     = "MIT"
  gem.summary     = "A Graphite dashboard for the command line."

  gem.executables = "casseo"
  gem.files       = %w( README.md Rakefile )
  gem.files       += Dir["lib/**/*"]
  gem.files       += Dir["bin/**/*"]
end
