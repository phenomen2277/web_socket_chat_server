# coding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'web_socket_chat_server/version'

Gem::Specification.new do |spec|
  spec.name          = "web_socket_chat_server"
  spec.version       = WebSocketChatServer::VERSION
  spec.authors       = ["Jone Samra"]
  spec.email         = ["jonemob@gmail.com"]
  spec.summary       = %q{A wrapper class for em-websocket (https://github.com/igrigorik/em-websocket) implementing a custom chat server protocol.}
  spec.description   = %q{For more details, please read the documentation at http://abulewis.com/doc/WebSocketChatServer.html}
  spec.homepage      = "https://github.com/phenomen2277/web_socket_chat_server"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.0.0"

  spec.add_runtime_dependency "em-websocket", "~> 0.5.1"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
