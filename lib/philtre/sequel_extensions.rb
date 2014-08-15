# TODO docs for this
class Sequel::Dataset
  include Ripar

  # make the roller understand dataset method
  def roller
    rv = super
    class << rv
      def to_dataset; riven end
    end
    rv
  end

  # roll the block and return the resulting dataset immediately
  def rolled( &blk )
    roller.rive &blk
  end
end

class Sequel::Dataset
  # filter must respond_to expr_hash and order_hash
  # will optionally yield a Grinder instance to the block
  def grind( filter = Philtre::Filter.new, apply_unknown: true )
    grinder = Philtre::Grinder.new filter
    t_dataset = grinder.transform self, apply_unknown: apply_unknown
    # only yield after the transform, so the grinder has the place holders
    yield grinder if block_given?
    t_dataset
  end
end
