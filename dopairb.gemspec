# frozen_string_literal: true

require_relative "lib/dopairb/version"

Gem::Specification.new do |spec|
  spec.name = "dopairb"
  spec.version = Dopairb::VERSION
  spec.authors = ["Koichi Sasada"]
  spec.email = ["ko1@atdot.net"]
  spec.summary = "IRB where every keystroke, result and exception gets a show"
  spec.description = "dopairb extends IRB with game-like terminal effects: sparks while typing, " \
                     "a wind-up and impact on every evaluation, big banners for combos and comebacks, " \
                     "and readable plain text left behind for copy & paste."
  spec.homepage = "https://github.com/ko1/dopairb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "LICENSE", "spec.md"]
  spec.bindir = "exe"
  spec.executables = ["dopairb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "irb", ">= 1.14", "< 2"
  spec.add_dependency "reline", ">= 0.5", "< 0.8"
end
