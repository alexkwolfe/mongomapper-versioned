require 'active_support/concern'

module Versioned  
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
      key :version_id, String, default: proc { SecureRandom.hex(16) }      
      
      many :versions, :as => :versioned, :sort => :id2.desc do 
        def where_id(id)
          ids = Array(id).collect(&:to_s)
          query = if ids.all?{|id| BSON::ObjectId.legal?(id.to_s) }
            where('id' => { '$in' => ids.collect{|id| BSON::ObjectId.from_string(id) } })
          else
            where('doc.version_id' => { '$in' => ids })
          end
        end
        
        def find(id)
          where_id(id).first
        end
      end
      
      before_update :push_version
      after_update :prune_versions
      after_destroy :destroy_versions
      
      cattr_accessor :max_versions
      attr_accessor :updater
      attr_writer :rolling_back
    end
    
    def rolling_back?
      !!@rolling_back
    end
    
    def pushing_version?
      !!@pushing_version
    end
    
    def save(options={})
      self.updater = options.delete(:updater)
      super
    end
    
    def push_version
      if rolling_back?
        persisted = self.class.find(self._id)
        self.versions.create(doc: persisted.version_doc, updater: self.updater)
      elsif !self.changes.empty?
        self.versions.create(doc: version_doc, updater: self.updater)
        self.generate_version_id
      end
    ensure
      self.updater = nil
    end
    
    def generate_version_id
      version_id = SecureRandom.hex(16)
      # don't use #save; that'll generate a new version
      self.write_attribute(:version_id, version_id)
      self.collection.update({'_id' => self._id}, { 'version_id' => version_id })
      self.changed_attributes.clear
    end
    
    def prune_versions
      if self.keep_versions_created_before
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
    
    def rollback(version)
      self.rolling_back = true
      self.version_id = version.doc['version_id']
      self.update_attributes(version.doc)
    ensure
      self.rolling_back = false 
    end

  end
end
