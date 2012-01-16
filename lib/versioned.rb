require 'mongo_mapper'
require File.join(File.dirname(__FILE__), 'versioned', 'version')
require File.join(File.dirname(__FILE__), 'versioned', 'versioned')

MongoMapper::Document.plugin(Versioned)

# module Versioned
#   
#   VERSION = '0.0.1'
#   
#   class Engine < ::Rails::Engine
#     initializer "railtie.initialize" do |app|
#       # Make sure config is set to reload plugins.
#       raise "Add 'config.reload_plugins = true' to your application.rb file" unless app.config.reload_plugins
# 
#       MongoMapper::Document.plugin(Versioned)
#     end
#   end
#end