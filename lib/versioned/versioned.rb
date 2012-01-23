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

      many :versions, :as => :versioned, :sort => :id2.desc, :dependent => :destroy do
        def where_id(id)
          ids = Array(id).collect(&:to_s)
          if ids.all? { |id| BSON::ObjectId.legal?(id.to_s) }
            where('id' => {'$in' => ids.collect { |id| BSON::ObjectId.from_string(id) }})
          else
            where('doc.version_id' => {'$in' => ids})
          end
        end

        def find(id)
          where_id(id).first
        end
      end

      before_update :prepare_version
      after_update :push_version
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

    def update(options={})
      return super if rolling_back?
      options.reverse_merge!(:validate => true)
      return false unless (!options[:validate] || valid?)
      run_callbacks(:update) {
        begin
          self.collection.update({:_id => self.id, :version_id => self.version_id}, to_mongo, :upsert => true, :safe => true)['updatedExisting']
        rescue Mongo::OperationFailure => e
          raise e unless e.error_code == 11000
          version_id = self.class.where(:_id => self.id).fields(:version_id).first.try(:version_id)
          raise ConflictingVersionError.new(version_id)
        end
      }
    end

    def prepare_version
      @_version = {
        version_id: SecureRandom.hex(16),
        doc:        self.version_doc
      }
    end

    def push_version
      if !self.changes.empty?
        clear_changes {
          self.versions.create(doc: @_version[:doc], updater: self.updater).tap do |created|
            self.save_version_id if created && !rolling_back?
          end
        }
      end
    ensure
      self.updater = nil
      @_version    = nil
    end

    def save_version_id
      # don't use #save; that'll generate a new version
      self.write_attribute(:version_id, @_version[:version_id])
      self.set(:version_id => @_version[:version_id])
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
      doc = {}
      doc.merge!(self.attributes)
      self.changes.each_pair { |attr, vals| doc[attr] = vals.first }
      doc.delete('_id')
      doc
    end

    def rollback(version)
      self.rolling_back = true
      self.version_id   = version.doc['version_id']
      self.update_attributes(version.doc)
    ensure
      self.rolling_back = false
    end

  end

  class ConflictingVersionError < RuntimeError
    attr_reader :version_id

    def initialize(version_id=nil)
      @version_id = version_id
      super("Attempted to update out-of-date document")
    end
  end
end
