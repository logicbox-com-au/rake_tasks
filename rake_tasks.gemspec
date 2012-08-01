# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rake_tasks/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Rich Larcombe, Ben Bruscella"]
  gem.email         = ["rich@logicbox.com.au, ben@logicbox.com.au"]
  gem.description   = %q{LogicBox set of rake tasks}
  gem.summary       = %q{LogicBox set of rake tasks}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "rake_tasks"
  gem.require_paths = ["lib"]
  gem.version       = RakeTasks::VERSION
end
