# frozen_string_literal: true

require_relative "lib/oaken/version"

Gem::Specification.new do |spec|
  spec.name          = "oaken"
  spec.version       = Oaken::VERSION
  spec.authors       = ["Waruna"]
  spec.summary       = "High-performance Ruby JSON serializer"
  spec.description   = "Fast JSON serialization using Oj with a simple class-based API"
  spec.homepage      = "https://github.com/yourusername/oaken"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  spec.files         = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "oj", "~> 3.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
