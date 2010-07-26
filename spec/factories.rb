# http://github.com/thoughtbot/factory_girl

Factory.define :user do |f|
  f.name             "John Doe"
  f.sequence(:email) { |n| "email#{n}@user.com" }
  f.password         "123456"
end

Factory.define :invited_user, :parent => :user do |f|
  f.password nil
end

Factory.define :admin do |f|
  f.sequence(:email) { |n| "email#{n}@admin.com" }
  f.password         "123456"
end