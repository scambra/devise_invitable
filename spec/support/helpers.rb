module Helpers
  
  def emails_sent(emails_count = 1, &block)
    lambda { yield }.should change(ActionMailer::Base.deliveries, :size).by(emails_count)
  end
  
  def emails_not_sent(&block)
    lambda { yield }.should_not change(ActionMailer::Base.deliveries, :size)
  end
  
  def store_translations(locale, translations, &block)
    begin
      I18n.backend.store_translations(locale, translations)
      yield
    ensure
      I18n.reload!
    end
  end
  
end

Rspec.configuration.include(Helpers)