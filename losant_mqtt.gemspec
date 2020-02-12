$LOAD_PATH.push(File.expand_path("../lib", __FILE__))
require "losant_mqtt/version"

Gem::Specification.new do |gem|
  gem.name          = "losant_mqtt"
  gem.authors       = ["Michael Kuehl"]
  gem.email         = ["hello@losant.com"]
  gem.summary       = %q{An MQTT client for the Losant MQTT Broker}
  gem.description   = %q{Easily use the Losant IoT Platform through its MQTT Broker with Ruby}
  gem.homepage      = "https://www.losant.com"
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.require_paths = ["lib"]
  gem.version       = LosantMqtt::VERSION
  gem.licenses      = ["MIT"]

  gem.required_ruby_version = ">= 2.1"

  gem.add_runtime_dependency "eventmachine", "~> 1.2"
  gem.add_runtime_dependency "mqtt", "~> 0.5"
  gem.add_runtime_dependency "events", "~> 0.9"

  gem.add_development_dependency "rspec", "~> 3.9"
  gem.add_development_dependency "rake", "~> 12"
end
