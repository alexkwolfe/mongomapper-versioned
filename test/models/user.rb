class User
  include MongoMapper::Document

  versioned
  timestamps!

  key :name, String
  key :email, String

  many :posts
end
