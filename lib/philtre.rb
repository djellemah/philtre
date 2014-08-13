require 'philtre/filter.rb'
require 'philtre/grinder.rb'

module Philtre
  # Really just a factory method that calls Filter.new
  # @filter = Philtre.new params[:filter]
  def self.new( *args, &blk )
    Filter.new *args, &blk
  end

  # This is the high-level, easy-to-read smalltalk-style interface
  # params:
  # - dataset is a Sequel::Model or a Sequel::Dataset
  # - with is the param hash
  # for xample, in rails you could do
  #  @personages = Philtre.filter dataset: Personage, with: params[:filter]
  # although
  def self.filter( dataset: nil, with: {}, **kwargs )
    puts with.inspect
    puts kwargs.inspect
    Filter.new(with.merge kwargs).apply(dataset)
  end

  def self.grind( dataset, with: {} )
    alias filter new
  end
end

require 'philtre/core_extensions.rb'

# And this is the even higher-level smalltalk-style interface
#  Philtre dataset: Personage, with: params[:filter]
module Kernel
private
  def Philtre( dataset: nil, with: {}, **kwargs )
    Philtre.filter dataset: dataset, with: with, **kwargs
  end

  alias philtre Philtre
end
