require 'ostruct'

class Philtre::Filter
  # These define the interface as used by the views.
  # So this class is available for custom predicates.
  class Model < OpenStruct
    extend ActiveModel::Naming

    # Name this as 'filter', so the parameters come back from the form as that.
    def self.model_name; ActiveModel::Name.new(Philtre); end

    # Rest of ActiveModel compliance, because
    #  include ActiveModel::Model
    # messes with initialize, which breaks OpenStruct
    def persisted?; false; end
    def to_key; nil; end
    def to_param; nil; end
    def errors; @errors ||= ActiveModel::Errors.new(self); end
    def to_partial_path; 'filter'; end
    def to_model; self; end
  end

  # TODO If your model does not act like an Active Model object, then you
  # should define :to_model yourself returning a proxy object that wraps your
  # object with Active Model compliant methods.
  # 07-May-2014 Nice idea, except that (at least from 4.0.2) rails uses to_model only in some
  # cases to get naming, and the original object gets passed to the FormBuilder.
  # Which is a bit stoopid.
  def to_model
    raise "Use for_form, you can't pass #{self} directly into a form_for call."
  end

  def for_form
    Model.new filter_parameters.reject{|k,v| v.blank?}
  end
end
