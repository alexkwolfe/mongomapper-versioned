require 'active_support/core_ext/array/conversions'
require 'mongomapper_id2'
require 'yajl'

class Version
  include MongoMapper::Document

  auto_increment!
  
  key :doc, Hash
  key :created_at, Time
  
  before_create :set_created_at, :encode_doc
  
  belongs_to :versioned, polymorphic: true
  belongs_to :updater, polymorphic: true
  
  def version_id
    doc['version_id']
  end
  
  class << self
    def check_indexes
      unless missing_indexes.empty?
        msg = "Indexes have not been created for MongoMapper versioned docs. Run `rake versioned:create_indexes`."
        if Kernel.const_defined?(:IRB)
          puts "Warning: #{msg}"
        else
          ::Rails.logger.warn(msg)
        end
      end
    end
    
    def missing_indexes
      existing_index_names = self.collection.index_information.keys
      required_index_names = required_indexes.collect do |i| 
        i.first.collect { |k| "#{k[0]}_#{k[1]}" }.join('_')
      end
      required_index_names - existing_index_names
    end

    def create_indexes
      required_indexes.each do |index|
        ensure_index *index
      end
    end
    
    def required_indexes
      [
        [[[:versioned_id, 1], [:versioned_type, 1], ['doc.version_id', 1]], background: true ],
        [[[:versioned_id, 1], [:versioned_type, 1], [:created_at, -1]], background: true ],
        [[[:versioned_id, 1], [:versioned_type, 1], [:id2, -1]], background: true],
        [[[:versioned_id, 1], [:versioned_type, 1], [:id2, 1]], background: true]
      ]
    end
  end
  
  protected
  # Update the created_at field on the Document to the current time. This is only called on create.
  def set_created_at
    unless self.created_at
      self.created_at = Time.now.utc 
    end
  end
  
  def encode_doc
    self.doc = Yajl::Parser.new.parse(Yajl::Encoder.encode(self.doc))
  end
end
