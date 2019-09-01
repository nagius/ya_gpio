lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'ya_gpio/version'

Gem::Specification.new do |s|
  s.name        = 'ya_gpio'
  s.version     = YaGPIO::VERSION
  s.date        = Time.now.utc.strftime("%Y-%m-%d")
  s.summary     = "GPIO module for Raspberry Pi"
  s.description = "YaGPIO is yet another GPIO ruby gem for Raspberry Pi"
  s.authors     = ["Nicolas AGIUS"]
  s.email       = 'nicolas.agius@lps-it.fr'
  s.files       = `git ls-files`.split("\n")
  s.test_files  = s.files.grep(%r{^(test|spec)/})
  s.homepage    = 'https://github.com/nagius/ya_gpio'
  s.metadata    = { "source_code_uri" => "https://github.com/nagius/ya_gpio" }
  s.license     = 'GPL-3.0'
  s.add_development_dependency 'rspec', '~> 3.8'
  s.add_development_dependency 'fakefs', '~> 0.20'
  s.add_development_dependency 'yard', '~> 0.9'
end

