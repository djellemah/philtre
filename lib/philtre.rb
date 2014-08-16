require 'philtre/filter.rb'
require 'philtre/grinder.rb'

# The high-level interface to Philtre. There are several ways
# to use it:
# 1. Philtre.new
#     philtre = Philtre.new name: 'Moustafa'
# 1. Philtre
#     philtre = Philtre dataset: some_dataset, age_gt: 21
#     philtre = Philtre dataset: some_dataset, with {age_gt: 21}
# 1. Philtre.filter
#     philtre = Philtre.filter dataset: some_dataset, name: 'Moustafa', age_gt: 21
#     philtre = Philtre.filter dataset: some_dataset, with: {name: 'Moustafa', age_gt: 21}
module Philtre
  # Just a factory method that calls Filter.new
  #
  #  philtre = Philtre.new params[:filter]
  def self.new( *args, &blk )
    Filter.new *args, &blk
  end

  # This is the high-level, easy-to-read smalltalk-style interface
  # params:
  # - dataset is a Sequel::Model or a Sequel::Dataset
  # - with is the param hash (optional, or just use hash-style args)
  #
  # for x-ample, in rails you could do
  #
  #  @personages = Philtre.filter dataset: Personage, with: params[:filter]
  #
  # or even
  #
  #  @personages = Philtre.filter dataset: Personage, name: 'Dylan', age_gt: 21, age_lt: 67
  #
  def self.filter( dataset: nil, with: {}, **kwargs )
    new(with.merge kwargs).apply(dataset)
  end

  # same as
  #  dataset = YourModel.filter( :name.lieu, )
  def self.grind( dataset, with: {} )
    alias filter new
  end
end

require 'philtre/core_extensions.rb'

# And this is the even higher-level smalltalk-style interface
#
#  Philtre dataset: Personage, with: params[:filter]
module Kernel
private
  def Philtre( dataset: nil, with: {}, **kwargs )
    Philtre.filter dataset: dataset, with: with, **kwargs
  end

  alias philtre Philtre
end
