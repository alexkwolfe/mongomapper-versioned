namespace :versioned do
  desc "Check MongoMapper Versioned plugin indexes"
  task :check_indexes => :environment do
    missing = Version.missing_indexes
    if missing.empty?
      puts "Indexes have already been created."
    else
      puts "Indexes have not been created. Run `rake versioned:create_indexes`."
    end
  end
  
  desc "Create MongoMapper Versioned plugin indexes"
  task :create_indexes => :environment do
    Version.create_indexes
  end
end