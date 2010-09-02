require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :specs do
  Dir[File.join(File.dirname(__FILE__), 'spec', 'orm', '*.rb')].each do |file|
    system "rake spec DEVISE_ORM=#{File.basename(file).split('.')[0]}"
  end
end

desc 'Default: run specs for all ORMs.'
task :default => :specs