# frozen_string_literal: true

class ActiveSupport::TestCase
  class_attribute :email_count, instance_accessor: false, default: 0

  def setup_mailer
    Devise.mailer = 'Devise::Mailer'
    ActionMailer::Base.deliveries = []
  end

  def store_translations(locale, translations, &block)
    I18n.backend.store_translations locale, translations
    yield
  ensure
    I18n.reload!
  end

  # Helpers for creating new users
  #
  def generate_unique_email
    ActiveSupport::TestCase.email_count += 1
    "test#{ActiveSupport::TestCase.email_count}@email.com"
  end

  def valid_attributes(attributes = {})
    {email: generate_unique_email,
     password: '123456',
     password_confirmation: '123456'}.update(attributes)
  end

  def new_user(attributes = {})
    User.new(valid_attributes(attributes))
  end
end
