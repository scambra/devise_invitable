require 'spec_helper'
require 'rails/generators'
require 'generators/devise_invitable/devise_invitable_generator'

describe DeviseInvitable::Generators::DeviseInvitableGenerator, :slow => true do
  RAILS_APP_PATH = File.expand_path("../../rails_app", __FILE__)
  
  describe "rails g" do
    before(:each) { @output = `cd #{RAILS_APP_PATH} && rails g` }
    
    it "should include the 3 generators" do
      @output.should include("DeviseInvitable:\n  devise_invitable\n  devise_invitable:install\n  devise_invitable:views")
    end
  end
  
  describe "rails g devise_invitable:install" do
    before(:all) { @output = `cd #{RAILS_APP_PATH} && rails g devise_invitable:install -p` }
    
    it "should include inject  config/initializers/devise.rb" do
      @output.should =~ %r(inject.+  config/initializers/devise\.rb\n)
    end
    it "should include create  config/locales/devise_invitable.en.yml" do
      @output.should =~ %r(create.+  config/locales/devise_invitable\.en\.yml\n)
    end
  end
  
  describe "rails g devise_invitable:views" do
    context "not scoped" do
      before(:all) { @output = `cd #{RAILS_APP_PATH} && rails g devise_invitable:views -p` }
      
      it "should include create  app/views/devise" do
        @output.should =~ %r(create.+  app/views/devise\n)
      end
      it "should include create  app/views/devise/invitations/edit.html.erb" do
        @output.should =~ %r(create.+  app/views/devise/invitations/edit\.html\.erb\n)
      end
      it "should include create  app/views/devise/invitations/new.html.erb" do
        @output.should =~ %r(create.+  app/views/devise/invitations/new\.html\.erb\n)
      end
      it "should include   app/views/devise/mailer/invitation_instructions.html.erb" do
        @output.should =~ %r(create.+  app/views/devise/mailer/invitation_instructions\.html\.erb\n)
      end
    end
    
    context "scoped" do
      before(:all) { @output = `cd #{RAILS_APP_PATH} && rails g devise_invitable:views octopussies -p` }
      
      it "should include create  app/views/octopussies" do
        @output.should =~ %r(create.+  app/views/octopussies\n)
      end
      it "should include create  app/views/octopussies/invitations/edit.html.erb" do
        @output.should =~ %r(create.+  app/views/octopussies/invitations/edit\.html\.erb\n)
      end
      it "should include create  app/views/octopussies/invitations/new.html.erb" do
        @output.should =~ %r(create.+  app/views/octopussies/invitations/new\.html\.erb\n)
      end
      it "should include   app/views/octopussies/mailer/invitation_instructions.html.erb" do
        @output.should =~ %r(create.+  app/views/octopussies/mailer/invitation_instructions\.html\.erb\n)
      end
    end
    
    pending "haml" do
      before(:all) do
        RailsApp::Application.config.generators.options[:rails][:template_engine] = :haml
        @output = `cd #{RAILS_APP_PATH} && rails g devise_invitable:views octopussies -p`
        puts RailsApp::Application.config.generators.options[:rails][:template_engine]
      end
      
      it "should include create  app/views/octopussies" do
        @output.should =~ %r(create.+  app/views/octopussies\n)
      end
      it "should include create  app/views/octopussies/invitations/edit.html.haml" do
        @output.should =~ %r(create.+  app/views/octopussies/invitations/edit\.html\.haml\n)
      end
      it "should include create  app/views/octopussies/invitations/new.html.erb" do
        @output.should =~ %r(create.+  app/views/octopussies/invitations/new\.html\.haml\n)
      end
      it "should include   app/views/octopussies/mailer/invitation_instructions.html.erb" do
        @output.should =~ %r(create.+  app/views/octopussies/mailer/invitation_instructions\.html\.haml\n)
      end
    end
  end
  
  describe "rails g devise_invitable Octopussy" do
    before(:each) { @output = `cd #{RAILS_APP_PATH} && rails g devise_invitable Octopussy -p` }
    
    it "should include inject  app/models/octopussy.rb" do
      @output.should =~ %r(inject.+  app/models/octopussy\.rb\n)
    end
    it "should include invoke  active_record" do
      @output.should =~ %r(invoke.+  #{DEVISE_ORM}\n)
    end
    it "should include create    db/migrate/\d{14}_devise_invitable_add_to_octopussies.rb if orm is ActiveRecord" do
      if DEVISE_ORM == :active_record
        @output.should =~ %r(create.+  db/migrate/\d{14}_devise_invitable_add_to_octopussies\.rb\n)
      elsif DEVISE_ORM == :mongoid
        @output.should_not =~ %r(create.+  db/migrate/\d{14}_devise_invitable_add_to_octopussies\.rb\n)
      end
    end
  end
end