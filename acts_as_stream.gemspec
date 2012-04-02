$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "acts_as_stream/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "acts_as_stream"
  s.version     = ActsAsStream::VERSION
  s.authors     = ["John Metta"]
  s.email       = ["mail@johnmetta.com"]
  s.homepage    = "http://github.com/mettadore/acts_as_stream"
  s.summary     = "Rails injectable Redis-backed activity stream system"
  s.description = "Rails injectable Redis-backed activity stream system. This is an alpha release of code that I just wrote and put into production on 3/11/12. Send feedback and post bugs to the Github page, but use at your own risk!"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 3.1"
  s.add_dependency "redis"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "acts_as_amico"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "spork", '~> 0.9.0'
  s.add_development_dependency 'guard-rspec'
  s.add_development_dependency 'guard-spork'
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "simplecov"
  s.add_development_dependency 'fakeweb'
  s.add_development_dependency 'uuidtools'
end
