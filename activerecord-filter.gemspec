require File.expand_path("../lib/active_record/filter/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name          = "activerecord-filter"
  spec.version       = ActiveRecord::Filter::VERSION
  spec.licenses      = ['MIT']
  spec.authors       = ["Jon Bracy"]
  spec.email         = ["jonbracy@gmail.com"]
  spec.homepage      = "https://github.com/malomalo/activerecord-filter"
  spec.description   = %q{A safe way to accept user parameters and query against your ActiveRecord Models}
  spec.summary       = %q{A safe way to accept user parameters and query against your ActiveRecord Models}

  spec.extra_rdoc_files = %w(README.md)
  spec.rdoc_options.concat ['--main', 'README.md']

  spec.files         = `git ls-files -- README.md {lib,ext}/*`.split("\n")
  spec.test_files    = `git ls-files -- {test}/*`.split("\n")
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activerecord', '~> 5.1'
  spec.add_runtime_dependency 'actionpack', '~> 5.1'
  spec.add_runtime_dependency 'arel-extensions', '~> 1.5.2'
    
  spec.add_development_dependency "pg"
  spec.add_development_dependency "bundler", '~> 1.11', '>= 1.11.2'
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "railties", '>= 5.0.0'
  spec.add_development_dependency "faker"
  spec.add_development_dependency "byebug"
  # spec.add_development_dependency 'sdoc',                '~> 0.4'
  # spec.add_development_dependency 'sdoc-templates-42floors', '~> 0.3'

end
