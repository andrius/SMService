lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "smservice/version"

Gem::Specification.new do |s|
  s.name          = "SMService"
  s.version       = SMService::VERSION
  s.authors       = ["Andrius Kairiukstis"]
  s.email         = ["k@andrius.mobi"]

  s.summary       = %q{Service Manager client.}
  s.description   = %q{Service Manager client with ZeroMQ DEALER endpoints, to build voice test automation actions based on ruby.}
  s.homepage      = "https://github.com/andrius/smservice"
  s.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # if s.respond_to?(:metadata)
  #   s.metadata["allowed_push_host"] = "https://rubygems.org"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against " \
  #     "public gem pushes."
  # end

  s.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  # s.bindir        = "bin"
  # s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.executables = []
  s.require_paths = ["lib"]
 
  s.add_runtime_dependency "logger", "~> 1.2"
  s.add_runtime_dependency "msgpack", "~> 1.1"
  s.add_runtime_dependency "ffi-rzmq", "~> 2.0"


  s.add_development_dependency "bundler", "~> 1.16"
  s.add_development_dependency "pry", "~> 0.11"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency "rspec", "~> 3.0"
end
