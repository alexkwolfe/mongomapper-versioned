class User
  include MongoMapper::Document

  versioned

  key :name, String
  key :email, String

  many :posts
end
