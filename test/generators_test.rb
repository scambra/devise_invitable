# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))
require 'test_helper'
require 'rails/generators'
require 'generators/devise_invitable/devise_invitable_generator'

class GeneratorsTest < ActiveSupport::TestCase
  RAILS_APP_PATH = File.expand_path('rails_app', __dir__)

  test 'rails g should include the generators' do
    @output     = `cd #{RAILS_APP_PATH} && rails g`
    generators  = %w[devise_invitable devise_invitable:form_for devise_invitable:install
                     devise_invitable:invitation_views devise_invitable:simple_form_for devise_invitable:upgrade
                     devise_invitable:upgrade_invitation_digests devise_invitable:views]

    generators.each do |generator|
      assert_includes @output, generator
    end
  end
end
