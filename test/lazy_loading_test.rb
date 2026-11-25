# frozen_string_literal: true

require 'test_helper'
require 'open3'

class LazyLoadingTest < ActiveSupport::TestCase
  LIBRARY = File.expand_path('../lib', __dir__)

  test 'loading devise invitable does not load Active Job' do
    script = <<~RUBY
      $LOAD_PATH.unshift #{LIBRARY.inspect}
      require 'devise_invitable'
      abort 'Active Job was loaded' if defined?(ActiveJob::Base)
    RUBY
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-e', script)

    assert status.success?, stderr
  end

  test 'Mongoid pending invitations retain the explicit foreign key without an inverse' do
    script = <<~RUBY
      $LOAD_PATH.unshift #{LIBRARY.inspect}
      require 'mongoid'
      require 'devise_invitable'
      require 'devise/orm/mongoid'

      class ResourceProbe
        include Mongoid::Document
        field :email, type: String
        devise :invitable
      end

      association = ResourceProbe.relations.fetch('pending_invitations')
      abort "Unexpected foreign key: \#{association.foreign_key}" unless association.foreign_key == 'invitable_id'
    RUBY
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-e', script)

    assert status.success?, stderr
  end
end
