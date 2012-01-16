require 'active_support/concern'

module Versioned
  
  VERSION = '0.0.1'
  
  extend ActiveSupport::Concern
  
  module ClassMethods
    def versioned(opts={})
      self.send(:include, Versioned::Document)
      self.max_versions = opts[:max].to_i
    end
  end
  
  module Document
    extend ActiveSupport::Concern
    
    included do      
      many :versions, :as => :versioned, :sort => :id2.desc
      
      before_update :push_version, :unless => :rolling_back?
      after_update :prune_versions
      after_destroy :destroy_versions
      
      cattr_accessor :max_versions
      attr_accessor :updater, :version_created_at
      attr_writer :rolling_back
    end
    
    def rolling_back?
      @rolling_back
    end
    
    def save(options={})
      options.assert_valid_keys(:updater, :version_created_at)
      self.updater = options.delete(:updater)
      self.version_created_at = options.delete(:version_created_at)
      super
    end

    # def save!(options={})
    #   options.assert_valid_keys(:safe, :updater, :version_created_at)
    #   save(options) || raise(DocumentNotValid.new(self))
    # end
    
    def push_version
      if self.changes.empty?
        #puts "SKIPPING VERSION because no changes"
      else
        version = self.versions.create(doc: version_doc, updater: self.updater)
        #puts "PUSH VERSION: #{version.inspect}"
      end
    ensure
      self.updater = nil
      self.version_created_at = nil
    end
    
    #
    # TEST ME!!!
    #
    def prune_versions
      #puts "UPDATED: #{[self.versions.first.created_at.utc, self.versions.first.doc['name']]}" if self.versions.first
      if self.keep_versions_created_before
        #puts "DESTROY VERSIONS OLDER THAN: #{self.keep_versions_until.utc}"
        #puts "TO BE DESTROYED: #{self.versions.where(:created_at.lt => self.keep_versions_until).collect{|v| [v.created_at, v.doc['name']]}}"
        self.versions.destroy_all(:created_at.lt => self.keep_versions_created_before)
      elsif self.class.max_versions
        limit = self.versions.count - self.class.max_versions
        if limit > 0
          self.versions.destroy_all(sort: 'id2 asc', limit: limit)
        end
      end
    end
    
    def keep_versions_created_before
      if self.respond_to?(:keep_versions_for)
        Time.now - self.keep_versions_for
      end
    end
    
    def destroy_versions
      self.versions.destroy_all
    end
    
    def version_doc
      {}.tap do |doc|
        doc.merge!(self.attributes)
        self.changes.each_pair do |attr, vals|
          doc[attr] = vals.first
        end
        doc.delete('_id')
      end
    end
    
    def rollback
      self.rolling_back = true
      yield
    ensure
      self.rolling_back = false
    end
    

  end
end
