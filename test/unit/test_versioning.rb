require 'test_helper'
require 'active_support/time_with_zone'
require 'tzinfo'

class VersioningTest < ActiveSupport::TestCase
  setup do
    Thread.current[:foo] = false
    Time.zone            = 'UTC'
    User.max_versions    = nil
    @user                = create_user
  end

  teardown do
    cleanup
  end

  context 'Versioned document' do
    should 'have versions' do
      assert @user.respond_to?(:versions)
      assert_equal [], @user.versions
    end

    should 'have version id' do
      assert @user.version_id.is_a?(String)
    end

    should 'not share version ids' do
      assert_not_equal @user.version_id, create_user.version_id
    end

    should 'not push version on empty update' do
      @user.save
      assert @user.versions.empty?
    end

    should 'not get a new version id on empty update' do
      version_id = @user.version_id
      @user.save
      assert_equal version_id, @user.version_id
    end

    context 'that has been updated' do
      setup do
        @version_id = @user.version_id
        @user.name  = "alex"
        @user.save
      end

      should 'push version' do
        assert_equal 1, @user.versions.size
      end

      should 'use version id' do
        assert_equal @version_id, @user.versions.first.version_id
      end

      should 'get a new version id' do
        assert_not_equal @version_id, @user.version_id
      end

      should 'rollback to previous version' do
        @user.rollback(@user.versions.first)
        assert_equal "Alex Wolfe", @user.name
      end

      should 'rollback version id' do
        @user.rollback(@user.versions.first)
        assert_equal @version_id, @user.version_id
      end

      should 'not store doc id in version doc' do
        doc = @user.versions.first.doc
        assert_nil doc['id']
        assert_nil doc['_id']
      end

      should 'store version_id in version doc' do
        doc = @user.versions.first.doc
        assert_equal @version_id, doc['version_id']
      end

      should 'not be updated when version_ids mismatch' do
        class << @user
          def version_id
            '123'
          end

          def attributes
            super.merge('version_id' => self.version_id)
          end
        end
        @user.name = "Foo"
        error = assert_raise(Versioned::ConflictingVersionError) do
         @user.save
        end
        assert_equal User.find(@user.id).version_id, error.version_id
        assert_equal 'alex', @user.reload.name
      end

      should 'update when version ids are the same' do
        @user2 = User.new(
          id: @user.id,
          version_id: @user.version_id,
          name: "Bobby",
          email: "bboy@bobbybrown.com"
        )
        @user2.save
        @user.reload
        assert_equal "Bobby", @user.name
      end
    end

    context 'that has been updated many times' do
      setup do
        @version_id = @user.version_id
        # Versions: Alex 4, Alex 3, Alex 2, Alex 1, Alex Wolfe
        (1..5).each do |i|
          @user.name = "Alex #{i}"
          assert @user.save
          assert_equal "Alex #{i}", @user.name
        end
        assert_equal "Alex 5", @user.name
      end

      should 'sort versions in reverse chronological order' do
        assert_equal @user.versions.to_a.sort { |x, y| y.id2 <=> x.id2 }, @user.versions.to_a
        assert_equal 5, @user.versions.count
        assert_equal "Alex 4", @user.versions.first.doc['name']
        assert_equal "Alex Wolfe", @user.versions.last.doc['name']
      end

      should 'find by version id' do
        version = @user.versions.find(@version_id)
        assert_equal @version_id, version.doc['version_id']
        assert_equal 'Alex Wolfe', version.doc['name']
      end

      context 'and has been rolled back' do
        setup do
          Thread.current[:foo] = true
          # second to oldest
          @version             = @user.versions[2]
          assert @user.rollback(@version), @user.errors.messages.inspect
        end

        should 'have original data' do
          assert_equal "Alex 2", @user.name
          assert_equal @version.doc['created_at'], @user.created_at.as_json

          # Unclear whether user should have the time the version was last updated
          # or the time the rollback was performed.
          #assert_equal @version.doc['updated_at'], @user.updated_at.as_json
        end

        should 'have original version id' do
          assert_equal @version.version_id, @user.version_id
        end

        should 'add a new version for the rollback' do
          assert_equal 6, @user.versions.count
          assert_equal 'Alex 5', @user.versions[0].doc['name'], @user.versions.collect { |v| v.doc['name'] }.inspect
          assert_equal 'Alex 4', @user.versions[1].doc['name']
          assert_equal 'Alex 3', @user.versions[2].doc['name']
          assert_equal 'Alex 2', @user.versions[3].doc['name']
          assert_equal 'Alex 1', @user.versions[4].doc['name']
          assert_equal 'Alex Wolfe', @user.versions[5].doc['name']
        end

        context 'and modified again' do
          setup do
            @user.name = "Alex 6"
            assert @user.save, @user.errors.messages.inspect
          end

          should 'have one more version' do
            assert_equal 7, @user.versions.count
          end

          should 'have the same version twice' do
            assert_equal 2, @user.versions.where_id(@version.version_id).count
          end
        end
      end
    end

    context 'that has been updated by a user' do
      setup do
        @updater   = User.create!(name: 'Bobby Brown', email: 'bobbeh@brown.com')
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
      5.downto(1).each do |i|
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
      @user2      = create_user
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
    end

    should 'have no more than max' do
      assert_equal 5, @user.versions.count
      assert_equal ["Alex 20", "Alex 19", "Alex 18", "Alex 17", "Alex 16"], @user.versions.collect { |v| v.doc['name'] }
    end
  end

  context 'Versioned document with time limit' do
    setup do
      class << @user
        def keep_versions_for
          5.minutes
        end
      end
      20.downto(1).each do |i|
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
        @user2      = create_user
        @user2.name = "Foo Bar"
        @user2.save!
      end
      @user.prune_versions
      assert_equal 1, @user2.versions.count
    end
  end
end
