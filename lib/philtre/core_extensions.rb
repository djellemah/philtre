# several ways to create placeholders in Sequel statements
module Kernel
private
  def PlaceHolder( name, sql_field = nil, bt = caller )
    Philtre::PlaceHolder.new name, sql_field, bt = caller
  end

  alias_method :Lieu, :PlaceHolder
end

class Symbol
  def lieu( sql_field = nil )
    Lieu self, sql_field, caller
  end

  def place_holder( sql_field = nil )
    PlaceHolder self, sql_field, caller
  end
end

unless Hash.instance_methods.include? :slice
  class Hash
    # return a hash containing only the specified keys
    def slice( *other_keys )
      other_keys.inject(Hash.new) do |hash, key|
        hash[key] = self[key] if has_key?( key )
        hash
      end
    end
  end
end
