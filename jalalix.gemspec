# frozen_string_literal: true

require_relative "lib/jalalix/version"

Gem::Specification.new do |spec|
  spec.name          = "jalalix"
  spec.version       = JalaliX::VERSION
  spec.authors       = ["Hossein Maklavani"]
  spec.email         = ["hossein@maklavani.dev"]

  spec.summary       = "Jalali (Persian / Shamsi) calendar for Ruby"
  spec.description   = "Pure Ruby port of JalaliX - same algorithm and camelCase API as the TypeScript package."
  spec.homepage      = "https://jalalix.com"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = "https://jalalix.com"
  spec.metadata["source_code_uri"] = "https://github.com/jalalix/ruby"
  spec.metadata["changelog_uri"] = "https://github.com/jalalix/ruby/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/jalalix/ruby/issues"
  spec.metadata["funding_uri"] = "https://opencollective.com/jalalix"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  end

  spec.require_paths = ["lib"]
end
