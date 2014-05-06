require 'rspec'
require 'faker'
require 'sequel'

require Pathname(__dir__).parent + 'lib/filter-sequel/grinder.rb'
Sequel.extension :blank
Sequel.extension :core_extensions

describe Grinder do
  def ds
    @ds ||= Sequel.mock[:t].filter( :name.lieu, :title.lieu ).order( :birth_year.lieu )
  end

  def grinder
    @grinder ||= Grinder.new
  end

  it 'shows placeholders' do
    ds.sql.should =~ /\$name/
    ds.sql.should =~ /\$title/
    ds.sql.should =~ /\$birth_year/
  end

  it 'collects placeholders' do
    nds = grinder.transform ds, apply_unknown: false
    grinder.places.flat_map{|k,v| v.keys}.should == %i[name title birth_year]
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
    grinder = Grinder.new Filter.new(blah: Faker::Name.name)
    ->{ grinder.transform( ds, apply_unknown: false ) }.should raise_error(/unknown placeholder/)
  end

  it 'raises on unknown order expressions' do
    grinder = Grinder.new Filter.new( :troll => :name.asc )
    ->{ grinder.transform( ds, apply_unknown: false ) }.should raise_error(/unknown placeholder/)
  end

  it 'substitutes expressions' do
    grinder = Grinder.new Filter.new( title: 'Jonathan Wrinklebottom' )
    nds = grinder.transform ds, apply_unknown: false
    nds.sql.should =~ /title = ['"`]Jonathan Wrinklebottom['"`]/i
  end

  it 'substitutes field names' do
    grinder = Grinder.new Filter.new( replace_this: 'Marna von Pffefferhaus' )
    nds = grinder.transform( ds.filter( :replace_this.lieu(:with_other) ), apply_unknown: false )
    nds.sql.should =~ /with_other = ['"`]Marna von Pffefferhaus['"`]/i
  end

  it 'handles order/where name clashes' do
    ods = ds.order( :name.lieu )
    grinder = Grinder.new Filter.new( name: 'Fannie Rosebottom', :order => 'name_desc')
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
    grinder = Grinder.new Filter.new( location: 'Spain', name: 'Bartholemew du Pince-Nez', :order => 'name_desc')
    nds = grinder.transform ds, apply_unknown: true
    grinder.unknown.should_not be_empty
    nds.sql.should =~ /Spain/
  end

  it 'ordering survives application of extra parameters' do
    pending "in Grinder#transform ordering parameters are stripped out by filter.subset"
    grinder = Grinder.new Filter.new( name: 'Finky Steetchas', :order => ['name_desc', 'dunno'])
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
      grinder = Grinder.new Filter.new(person_id: 42)
      nds = grinder.transform ds
      nds.sql.should =~ /person_id IN/
      nds.sql.should =~ /person_id\s*=\s*42/
    end
  end
end
