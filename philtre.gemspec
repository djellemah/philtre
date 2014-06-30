# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'philtre/version'

Gem::Specification.new do |spec|
  spec.name          = "philtre"
  spec.version       = Philtre::VERSION
  spec.authors       = ["John Anderson"]
  spec.email         = ["panic@semiosix.com"]
  spec.summary       = %q{The Sequel equivalent for Ransack, Metasearch, Searchlogic}
  spec.description   = %q{If this doesn't make you fall in love, I don't know what will.}
  spec.homepage      = "https://github.com/djellemah/philtre"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
