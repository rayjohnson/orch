# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'orch/version'

Gem::Specification.new do |spec|
  spec.name          = "orch"
  spec.version       = Orch::VERSION
  spec.authors       = ["Ray Johnson"]
  spec.email         = ["rjohnson@yp.com"]
  spec.summary       = %q{orch uses yaml to deploy to Mesos' Marathon and Chronos frameworks}
  spec.description   = %q{orch uses yaml to deploy to Mesos' Marathon and Chronos frameworks}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

  spec.add_dependency 'thor', '~> 0.18'
  spec.add_dependency 'hashie'

end
