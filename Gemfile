source 'https://rubygems.org'

gemspec
gem 'devise', :git => 'git://github.com/plataformatec/devise.git', :branch => 'rails4'
group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter'
  end

  platforms :ruby do
    gem "sqlite3", "~> 1.3.4"
  end

  gem 'activerecord', '~> 4.0.0.beta'
  #gem "mongoid", "~> 2.3"
  gem "bson_ext", "~> 1.3"
  gem "capybara", "~> 1.1.0"
  gem 'shoulda', '~> 2.11.3'
  gem 'mocha', '~> 0.9.9'
  gem 'factory_girl_rails', '~> 1.2'
  gem 'rspec-rails', '~> 2.12.0'
end
