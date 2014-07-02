# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'philtre/version'

Gem::Specification.new do |spec|
  spec.name          = 'philtre'
  spec.version       = Philtre::VERSION
  spec.authors       = ['John Anderson']
  spec.email         = ['panic@semiosix.com']
  spec.summary       = %q{http parameter-hash friendly filtering for Sequel}
  spec.description   = %q{Encode various filtering operations in http parameter hashes}
  spec.homepage      = 'http://github.com/djellemah/philtre'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'sequel'
  spec.add_dependency 'fastandand'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-debugger'
  spec.add_development_dependency 'pry-debundle'
  spec.add_development_dependency 'faker'
  spec.add_development_dependency 'sqlite3'
end
