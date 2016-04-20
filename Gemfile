source 'https://rubygems.org'

gemspec

group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter', '>= 1.3.0.beta1'
  end

  platforms :ruby do
    gem "sqlite3", "~> 1.3.4"
  end

  platforms :rbx do
    gem "rubysl"
    gem "rubysl-test-unit"
    gem "racc"
  end

  gem 'devise', '~> 4.0'
  gem 'activerecord', '~> 4.2.6'
  gem "mongoid"
  # gem "mongoid", :github => "mongoid/mongoid", :branch => "master"
  gem "capybara"
  #gem "launchy", "~> 2.4.3"
  gem 'shoulda', '~> 2.11.3'
  gem 'mocha'
  gem 'factory_girl_rails'
  gem 'nokogiri'
  gem 'rspec-rails'
end
