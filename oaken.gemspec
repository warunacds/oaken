# frozen_string_literal: true

require_relative "lib/oaken/version"

Gem::Specification.new do |spec|
  spec.name          = "oaken"
  spec.version       = Oaken::VERSION
  spec.authors       = ["Waruna"]
  spec.summary       = "High-performance Ruby JSON serializer"
  spec.description   = "Fast JSON serialization using Oj with a simple class-based API"
  spec.homepage      = "https://github.com/warunacds/oaken"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["source_code_uri"] = "https://github.com/warunacds/oaken"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files         = Dir["lib/**/*", "LICENSE", "README.md", "Rakefile"]
  spec.require_paths = ["lib"]

  spec.add_dependency "oj", "~> 3.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "benchmark-ips", "~> 2.0"
  spec.add_development_dependency "alba", "~> 3.0"
  spec.add_development_dependency "blueprinter", "~> 1.0"
end
