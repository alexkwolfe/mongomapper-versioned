require File.expand_path(File.dirname(__FILE__) + '/../../lib/versioned')

require 'benchmark'

MongoMapper.database = 'versioned_performance'
 
class Max
  include MongoMapper::Document

  versioned max: 10

  key :approved, Boolean
  key :count, Integer
  key :approved_at, Time
  key :expire_on, Date
end
Max.collection.remove

class Timed
  include MongoMapper::Document
  
  versioned

  key :approved, Boolean
  key :count, Integer
  key :approved_at, Time
  key :expire_on, Date
  
  def keep_versions_for
    1.second
  end
end
Timed.collection.remove

class None
  include MongoMapper::Document
  
  key :approved, Boolean
  key :count, Integer
  key :approved_at, Time
  key :expire_on, Date
end
None.collection.remove

Benchmark.bm(28) do |x|
  max_ids, timed_ids, ids = [], [], []
  x.report("write with versioning (max)  ") do
    1000.times { |i| max_ids << Max.create(:count => 0, :approved => true, :approved_at => Time.now, :expire_on => Date.today).id }
  end
  x.report("write with versioning (timed)") do
    1000.times { |i| timed_ids << Timed.create(:count => 0, :approved => true, :approved_at => Time.now, :expire_on => Date.today).id }
  end
  x.report("write without versioning     ") do
    1000.times { |i| ids << None.create(:count => 0, :approved => true, :approved_at => Time.now, :expire_on => Date.today).id }
  end
  x.report("read with versioning (max)   ") do
    max_ids.each { |id| Max.first(:id => id) }
  end
  x.report("read with versioning (timed) ") do
    timed_ids.each { |id| Timed.first(:id => id) }
  end
  x.report("read without versioning      ") do
    ids.each { |id| None.first(:id => id) }
  end
end
