module Shim
  extend ::ActiveSupport::Concern
  included do
    include ::Mongoid::Timestamps
  end
  
  module ClassMethods
    def last(options={})
      options.delete(:order) if options[:order] == "id"
      super(options)
    end
  end
  
  # overwrite equality (because some devise tests use this for asserting model equality) 
  def ==(other)
    other.is_a?(self.class) && _id == other._id
  end
end
