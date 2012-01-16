$LOAD_PATH.unshift('.') unless $LOAD_PATH.include?('.')

require File.expand_path(File.dirname(__FILE__) + '/../lib/versioned')
require 'test/config/config'

require 'pp'
require 'shoulda'
require 'timecop'

require 'test/models/post'
require 'test/models/user'


def create_user
  User.create(
    :name => 'Alex Wolfe', 
    :email => 'alexkwolfe@gmail.com',
    :posts => []
  )
end

def cleanup
  User.delete_all
  Version.delete_all
end




