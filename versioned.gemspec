# encoding: UTF-8
require File.join File.dirname(__FILE__), '/lib/versioned/meta'

Gem::Specification.new do |s|
  s.name                          = 'mongomapper-versioned'
  s.homepage                      = 'http://github.com/alexkwolfe/mongomapper-versioned'
  s.summary                       = 'A MongoMapper extension adding Versioning'
  s.require_paths                 = ['lib']
  s.authors                       = ['Alex Wolfe']
  s.email                         = 'alexkwolfe@gmail.com'
  s.version                       = Versioned::VERSION
  s.platform                      = Gem::Platform::RUBY
  s.files                         = Dir.glob('lib/**/*') + %w[Gemfile Rakefile README.md]
  s.test_files                    = Dir.glob('test/**/*')
  
  s.add_dependency 'yajl-ruby'
  s.add_dependency 'bson_ext'
  s.add_dependency 'mongo_mapper', '>= 0.10.1'
  s.add_dependency 'mongomapper_id2'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'shoulda'
  s.add_development_dependency 'ruby-debug19'
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'tzinfo'
end
