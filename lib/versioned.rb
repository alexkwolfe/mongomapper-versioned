require 'mongo_mapper'
require File.join(File.dirname(__FILE__), 'versioned', 'meta')
require File.join(File.dirname(__FILE__), 'versioned', 'version')
require File.join(File.dirname(__FILE__), 'versioned', 'versioned')

module Versioned  
  if Kernel.const_defined?(:Rails) && Rails.constants.include?(:Engine)
    class Engine < ::Rails::Engine
      engine_name :versioned
      initializer "versioned.initialize" do |app|
        MongoMapper::Document.plugin(Versioned)
      end
      initializer 'versioned.check_indexes', :after=> :disable_dependency_loading do
        Version.check_indexes
      end
    end
  else
    MongoMapper::Document.plugin(Versioned)
  end
end