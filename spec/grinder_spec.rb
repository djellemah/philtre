require 'rspec'
require 'faker'
require 'sequel'
require 'ripar'

require_relative '../lib/philtre.rb'

Sequel.extension :blank
Sequel.extension :core_extensions

describe Philtre::Grinder do
  def ds
    @ds ||= Sequel.mock[:t].filter( :name.lieu, :title.lieu ).order( :birth_year.lieu )
  end

  def other_ds
    @other_ds ||= Sequel.mock[:ods]
  end

  def grinder
    @grinder ||= Philtre::Grinder.new
  end

  it 'shows placeholders' do
    ds.sql.should =~ /\$name/
    ds.sql.should =~ /\$title/
    ds.sql.should =~ /\$birth_year/
  end

  it 'shows comments' do
    ds.sql.should =~ %r{\$name/\*\S+\*/}
    ds.sql.should =~ %r{\$title/\*\S+\*/}
    ds.sql.should =~ %r{\$birth_year/\*\S+\*/}
  end

  describe '#places' do
    it 'collects placeholders' do
      nds = grinder.transform ds, apply_unknown: false
      grinder.places.flat_map{|k,v| v.keys}.should == %i[name title birth_year]
    end

    it 'fails before transform' do
      ->{grinder.places}.should raise_error(/Call transform.*place/)
    end
  end

  describe '#unknown' do
    it 'fails before transform' do
      ->{grinder.unknown}.should raise_error(/Call transform.*not.*filter/)
    end

    it 'has a list of unknowns' do
      grinder = Philtre::Grinder.new Philtre::Filter.new( location: 'Spain', name: 'Bartholemew del Pince-Nez', :order => 'name_desc')
      nds = grinder.transform ds, apply_unknown: true
      grinder.unknown.should == %i[location]
    end
  end

  it 'removes empty expressions' do
    nds = grinder.transform ds, apply_unknown: false
    nds.sql.should_not =~ /name/
    nds.sql.should_not =~ /title/
    nds.sql.should_not =~ /birth_year/
  end

  it 'removes empty clauses' do
    nds = grinder.transform ds, apply_unknown: false
    nds.sql.should_not =~ /where/i
    nds.sql.should_not =~ /order by/i
  end

  it 'raises on unknown filter expressions' do
    grinder = Philtre::Grinder.new Philtre::Filter.new(blah: Faker::Name.name)
    ->{ grinder.transform( ds, apply_unknown: false ) }.should raise_error(/unknown value/)
  end

  it 'raises on unknown order expressions' do
    grinder = Philtre::Grinder.new Philtre::Filter.new( :troll => :name.asc )
    ->{ grinder.transform( ds, apply_unknown: false ) }.should raise_error(/unknown value/)
  end

  it 'substitutes expressions' do
    grinder = Philtre::Grinder.new Philtre::Filter.new( title: 'Jonathan Wrinklebottom' )
    nds = grinder.transform ds, apply_unknown: false
    nds.sql.should =~ /title = ['"`]Jonathan Wrinklebottom['"`]/i
  end

  it 'substitutes field names' do
    grinder = Philtre::Grinder.new Philtre::Filter.new( replace_this: 'Marna von Pffefferhaus' )
    nds = grinder.transform( ds.filter( :replace_this.lieu(:with_other) ), apply_unknown: false )
    nds.sql.should =~ /with_other = ['"`]Marna von Pffefferhaus['"`]/i
  end

  it 'handles order/where name clashes' do
    ods = ds.order( :name.lieu )
    grinder = Philtre::Grinder.new Philtre::Filter.new( name: 'Fannie Rosebottom', :order => 'name_desc')
    nds = grinder.transform ods, apply_unknown: false
    nds.sql.should == %q{SELECT * FROM t WHERE ((name = 'Fannie Rosebottom')) ORDER BY name DESC}
  end

  it 'handles subselects' do
    mds = Sequel.mock.from(ds.select(Sequel.lit 'sum(age) as age')).filter( :age.lieu )
    mds.sql.should =~ /age/
    nds = grinder.transform mds, apply_unknown: false
    nds.sql.should =~ %r{^SELECT \* FROM \(SELECT}
    nds.sql.should =~ /t1/
  end

  it 'applies extra parameters to the dataset after the placeholders' do
    grinder = Philtre::Grinder.new Philtre::Filter.new( location: 'Spain', name: 'Bartholemew del Pince-Nez', :order => 'name_desc')
    nds = grinder.transform ds, apply_unknown: true
    grinder.unknown.should_not be_empty
    nds.sql.should =~ /Spain/
  end

  it 'ordering survives application of extra parameters' do
    skip 'in Grinder#transform ordering parameters are stripped out by filter.subset'
    grinder = Philtre::Grinder.new Philtre::Filter.new( name: 'Finky Steetchas', :order => ['name_desc', 'dunno'])
    nds = grinder.transform ds, apply_unknown: true
    grinder.unknown.should_not be_empty
  end

  describe 'subset stack' do
    def ds
      @ds ||=
      begin
        subselect = Sequel.mock[:sub].select(:id)
        Sequel.mock[:t].filter( :name.lieu, :title.lieu, person_id: subselect ).order( :birth_year.lieu )
      end
    end

    it 'gets back to where after a subselect' do
      grinder = Philtre::Grinder.new Philtre::Filter.new(person_id: 42)
      nds = grinder.transform ds
      nds.sql.should =~ /person_id IN/
      nds.sql.should =~ /person_id\s*=\s*42/
    end
  end

  it 'handle sub-datasets' do
    grinder = Philtre::Grinder.new Philtre::Filter.new(person_id: 212728)
    tds = ds.filter( linkage: other_ds.where( :person_id.lieu ) )
    nds = grinder.transform tds
    nds.sql.should =~ /FROM\s+ods\s+WHERE\s*\(\s*person_id\s*=\s*212728\s*\)/
  end

  it 'handles rollers' do
    grinder = Philtre::Grinder.new Philtre::Filter.new(person_id: 212728)
    tds = ds.roller do
      where linkage: other_ds.where( :person_id.lieu )
    end
    tds.__class__.should == Ripar::Roller

    nds = grinder.transform tds
    nds.sql.should =~ /FROM\s+ods\s+WHERE\s*\(\s*person_id\s*=\s*212728\s*\)/
  end

  it 'handles Models' do
    Sequel::Model.db = Sequel.sqlite
    class Ods < Sequel::Model(:ods); end
    Philtre::Grinder.new( Philtre::Filter.new ).transform(Ods).should be_a(Sequel::Dataset)
    Philtre::Grinder.new( Philtre::Filter.new ).transform(Ods).sql.should =~ /SELECT \* FROM .ods./
  end
end
