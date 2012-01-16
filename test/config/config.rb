require 'mongo_mapper'

MongoMapper.database = YAML.load(File.read('test/config/database.yml'))[ENV['RACK_ENV']]['database'] rescue 'versioned_test'
