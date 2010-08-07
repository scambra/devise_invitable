# coding:utf-8
$:.unshift File.expand_path("../lib", __FILE__)

require 'rubygems'
require 'devise_invitable/version'

def gemspec
  @gemspec ||= begin
    file = File.expand_path('../rymai-devise_invitable.gemspec', __FILE__)
    eval(File.read(file), binding, file)
  end
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require 'rdoc/task'
RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "DeviseInvitable #{DeviseInvitable::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.options << "--charset=UTF-8"
end

begin
  require 'rake/gempackagetask'
rescue LoadError
  task(:gem) { $stderr.puts '`gem install rake` to package gems' }
else
  Rake::GemPackageTask.new(gemspec) do |pkg|
    pkg.gem_spec = gemspec
  end
  task :gem => :gemspec
end

desc "Validate the gemspec"
task :gemspec do
  gemspec.validate
end

desc "install the gem locally"
task :install => :gemspec do
  system "gem install pkg/rymai-devise_invitable-#{DeviseInvitable::VERSION}"
end

desc 'Run bundle install.'
task :bundle_install do
  system "bundle install"
end

desc 'Run DeviseInvitable specs for all ORMs.'
task :all_specs do
  Dir[File.join(File.dirname(__FILE__), 'spec', 'orm', '*.rb')].each do |file|
    system "rake spec DEVISE_ORM=#{File.basename(file).split('.')[0]}"
  end
end

desc "Run this task before commiting. Install the bundle's gems and run all specs"
task :pre_commit => [:bundle_install, :all_specs]

desc 'Default: run specs for all ORMs.'
task :default => :all_specs