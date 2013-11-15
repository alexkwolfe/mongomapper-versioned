*If you are interested in becoming the maintainer of this project, please let me know.*

## Versioned

Automatically store a version of a MongoMapper document every time it's updated. Configure a maximum number of versions you'd like to keep, or even the amount of time a particular document should keep versions around.

### Setup

Add the gem to your Gemfile. Add the necessary Mongo indexes: run `Version.create_indexes` in your console, or if you are using Rails run the `rake versioned:create_indexes` command.

### Basic Usage

Add the `versioned` declaration to the MongoMapper document models you want to keep versions of. When you update a versioned document, a new version will be stored. Deleting a stored document will delete all the associated versions.

````ruby
class User
  versioned

  key :name, String
  key :email, String
end
````

### Querying

Every versioned document model has an association called `versions` that contains all past versions of a document. It's a plain old MongoMapper one-to-many association with the `Version` model, sorted in reverse chronological order. You can query for versions using MongoMapper's standard query criteria:

````ruby
@user.versions.where(:created_at.lt > 1.day.ago)
````

### Pruning old versions

Use the `max` option to specifiy the maximum number of versions you want to keep. When the document is updated, the oldest versions will be pruned away to keep no more than the maximum number you specify.

````ruby
class User
  versioned max: 10

  key :name, String
  key :email, String
end
````

If you'd rather specify the amount of time the versions of a doc should be kept, implement `keep_versions_for`. It must return the number of seconds to keep each revision. Every time a new version is created, versions will be purged based on their age.

This doesn't work with the `max` option.  Use one or the other.

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

### Handling version conflicts

Attempting to update a document with an old `version_id` will result in a `Versioned::ConflictingVersionError`. Use the error's
`version_id` accessor to get the version of the currently stored document.

This feature is meant to prevent you from over-writing someone else's changes and give you the option of resolving the conflict
gracefully:

````ruby
@user = User.first
@user.name = "Bobby"
begin
  @user.save
rescue Versioned::ConflictingVersionError => e
  # Keep your changes
  @user.version_id = e.version_id
  @user.save

  # Or keep other person's changes
  # @user.reload
end

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

Each `Version` contains a copy of the document as it existed at a point in time. You can roll back to a particular version by calling the `rollback` method on the document, passing the version.

````ruby
@user.versions.count
=> 9
version = @user.versions[5]
@user.rollback(version)
=> true
@user.versions.count
=> 10
@user.version_id == @user.versions[5].version_id
=> true
````

##### What happens to the versions collection on rollback?

Rolling back a document will create a new version representing its persisted state just prior to rollback. When you rollback a document, then make changes on top of the rolled back document, the `versions` collection contains two Version instances with the same `version_id`.


### Version IDs

The `versions` collection contains all the previous versions of a document. The document itself represents the "current version." The document has a `version_id` key and when the document is updated its version id is stored with the Version. Then the document gets a new `version_id`.

Rolling back to a previous revision will also roll back the `version_id` value of the document.

This mechanism allows you to easily undo changes to a document:

````ruby
version_id = @user.version_id
@user.name
=> "Roger"

# change some stuff
@user.name = "Frank"
@user.save
@user.name = "Bob"
@user.save

# rollback
version = @user.versions.find(version_id)
@user.rollback(version)

# document is restored
@user.name
=> "Roger"
@user.version_id == version_id
=> true
````
