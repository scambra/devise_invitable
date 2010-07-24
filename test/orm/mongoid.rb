class ActiveSupport::TestCase
  setup do
    User.delete_all
    Admin.delete_all
  end
end