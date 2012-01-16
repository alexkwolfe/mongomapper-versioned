## Versioned

Automatically store a version of a MongoMapper document every time it's updated. Configure a maximum number of versions you'd like to keep, or even the amount of time a particular document should keep versions around.

### Setup

Make sure to add the necessary indexes. Run `Version.create_indexes` in your console.

### Basic Usage

Add the `versioned` declaration to the MongoMapper document models you want to keep versions of.

````ruby
class User
  # Only keep 10 versions of each user
  versioned max: 10
  
  key :name, String
  key :email, String
end
````

### Delete old versions

If you'd rather specify the amount of time the versions of a doc should be kept, implement `keep_versions_for`. It should return the number of seconds to keep each revision. This doesn't work with the `max` option.  Use one or the other.

Every time a new version is created, "old" versions will be purged based on their age.

````ruby
class User
  versioned
  
  key :name, String
  key :email, String
  
  def keep_versions_for
    90.days
  end
end
```` 

### Querying

Every versioned document model has a new association called `versions`. It's a plain old MongoMapper one-to-many association with the `Version` model, sorted in reverse chronological order. You can query for versions using MongoMapper criteria and the like:

````ruby
@user.versions.where(:created_at.lt > 1.day.ago)
````

### Auditing

When a versioned document is saved, you can pass the `updater` option to the save method. The associated version will keep a reference to the document passed. This allows you to keep track of who made a change to a versioned document.

````ruby
@reginold = User.find_by_email('reggie@hotmail.com')
@user.name = "Bob"
@user.save(:updater => @reginold)
@user.versions.first.updater
=> @reginold
````

### Rolling back

You can roll back to an old version by calling the `rollback` method on the version you want. Reload the versioned document to pull the changes into the reference you're holding to the document.

````ruby
@user.versions[5].rollback
@user.reload
````

