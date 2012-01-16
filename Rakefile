require 'rubygems'
require 'rake'

require File.join(File.dirname(__FILE__), '/lib/versioned')

require 'rake/testtask'
namespace :test do
  Rake::TestTask.new(:unit) do |test|
    test.libs << 'test'
    test.ruby_opts << '-rubygems'
    test.pattern = 'test/unit/**/test_*.rb'
    test.verbose = true 
  end

  Rake::TestTask.new(:performance) do |test|
    test.libs << 'test'
    test.ruby_opts << '-rubygems'
    test.pattern = 'test/performance/**/*.rb'
    test.verbose = true 
  end
end

task :default => 'test:unit'

desc 'Builds the gem'
task :build do
  sh 'gem build versioned.gemspec'
  Dir.mkdir('pkg') unless File.directory?('pkg')
  sh "mv mongomapper-versioned-#{Versioned::VERSION}.gem pkg/mongomapper-versioned-#{Versioned::VERSION}.gem"
end

desc 'Builds and Installs the gem'
task :install => :build do
  sh "gem install pkg/mongomapper-versioned-#{Versioned::VERSION}.gem"
end
