# coding:utf-8
$:.unshift File.expand_path("../lib", __FILE__)

require 'rubygems'
require 'devise_invitable/version'

def gemspec
  @gemspec ||= begin
    file = File.expand_path('../devise_invitable.gemspec', __FILE__)
    eval(File.read(file), binding, file)
  end
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/**/*_test.rb'].exclude('test/rails_app')
  test.verbose = true
end


require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = DeviseInvitable::VERSION
  
  rdoc.rdoc_dir = 'doc'
  rdoc.title = "DeviseInvitable #{version}"
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

desc "install the gem locally"
task :install => :package do
  sh %{gem install pkg/devise_invitable-#{DeviseInvitable::VERSION}}
end

desc "validate the gemspec"
task :gemspec do
  gemspec.validate
end

task :package => :gemspec
task :default => :test