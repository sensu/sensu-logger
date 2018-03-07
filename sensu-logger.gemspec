# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "sensu-logger"
  spec.version       = "1.2.2"
  spec.authors       = ["Sean Porter"]
  spec.email         = ["portertech@gmail.com", "engineering@sensu.io"]
  spec.summary       = "The Sensu logger library"
  spec.description   = "The Sensu logger library"
  spec.homepage      = "https://github.com/sensu/sensu-logger"
  spec.license       = "MIT"

  spec.files         = Dir.glob("lib/**/*") + %w[sensu-logger.gemspec README.md LICENSE.txt]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency("sensu-json")
  spec.add_dependency("eventmachine")

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"

  spec.cert_chain    = ["certs/sensu.pem"]
  spec.signing_key   = File.expand_path("~/.ssh/gem-sensu-private_key.pem") if $0 =~ /gem\z/
end
