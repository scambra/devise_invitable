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
end
