require 'test_helper'

class VersioningTest < ActiveSupport::TestCase
  setup do
    User.max_versions = nil
    @user = create_user
  end
  
  teardown do
    cleanup
  end
  
  context 'Versioned document' do
    should 'have versions' do
      assert @user.respond_to?(:versions)
      assert_equal [], @user.versions
    end
    
    should 'not push version on empty update' do
      @user.save
      assert @user.versions.empty?
    end

    context 'that has been updated' do
      setup do
        @user.name = "alex"
        @user.save
      end
      
      should 'push version' do
        assert_equal 1, @user.versions.size
      end
      
      should 'rollback to previous version' do 
        @user.versions.first.rollback
        @user.reload
        assert_equal "Alex Wolfe", @user.name
      end
    end
    
    context 'that has been updated many times' do
      setup do
        (1..5).each do |i|  
          @user.name = "Alex #{i}"
          @user.save!
        end
      end
      
      should 'rollback several versions' do
        assert @user.versions.last.rollback # oldest
        @user.reload
        assert_equal "Alex Wolfe", @user.name
      end
      
      should 'sort versions in reverse chronological order' do
        assert_equal @user.versions.to_a.sort {|x,y| y.created_at <=> x.created_at }, @user.versions.to_a
      end
    end
    
    context 'that has been updated by a user' do
      setup do
        @updater = User.create!(name: 'Bobby Brown', email: 'bobbeh@brown.com')
        @user.name = "alex"
        @user.save(updater: @updater)
      end
      
      should 'store user with version' do
        assert_equal @updater, @user.versions.first.updater
      end
      
      should 'forget user after save' do
        assert @user.updater.nil?
      end
    end
  end
  
  context 'Destroyed versioned document' do
    setup do
      (1..5).each do |i| 
        @user.name = "#{@user.name} #{i}"
        @user.save!
      end
    end
    
    should 'destroy versions' do
      @user.destroy
      assert_equal 0, Version.count
    end
    
    should 'not destroy versions of other documents' do
      assert_equal 5, Version.count
      
      @user2 = create_user
      @user2.name = "Foo"
      @user2.save
      @user2.name = "Bar"
      @user2.save
      
      assert_equal 7, Version.count
      
      @user.destroy
      
      assert_equal 2, Version.count
      assert_equal 2, @user2.versions.count
      assert_equal "Foo", @user2.versions.first.doc['name']
    end
  end
  
  context 'Versioned document with max versions' do
    setup do
      User.max_versions = 5
      (1..21).each do |i| 
        @user.name = "Alex #{i}"
        @user.save!
      end
      @user.reload
    end
    
    should 'have no more than max' do
      assert_equal 5, @user.versions.count
      assert_equal ["Alex 20", "Alex 19", "Alex 18", "Alex 17", "Alex 16"], @user.versions.collect{|v| v.doc['name']}
    end
  end
  
  context 'Versioned document with time limit' do
    setup do
      class << @user
        def keep_versions_for
          5.minutes
        end
      end
      (1..20).each do |i| 
        Timecop.freeze(i.minutes.ago) do
          @user.name = "Alex #{i}"
          @user.save!
        end
      end
    end
    
    should 'calculate time threshold' do
      assert_equal (Time.now.utc - 5.minutes).to_i, @user.keep_versions_created_before.to_i
    end
    
    should 'prune documents older than time limit' do
      @user.prune_versions
      assert_equal 4, @user.versions.count
      @user.versions.each do |v|
        assert v.created_at >= @user.keep_versions_created_before
      end
    end
    
    should "not prune other documents' versions" do
      Timecop.freeze(10.minutes.ago) do
        @user2 = create_user
        @user2.name = "Foo Bar"
        @user2.save!
      end
      @user.prune_versions
      assert_equal 1, @user2.versions.count
    end
  end
end
