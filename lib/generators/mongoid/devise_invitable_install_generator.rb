# frozen_string_literal: true

module Mongoid
  module Generators
    # Adds invitation fields to a Mongoid model.
    class DeviseInvitableInstallGenerator < Rails::Generators::Base
      desc 'DeviseInvitable stores its Mongoid field definitions in the gem model.'
    end
  end
end
