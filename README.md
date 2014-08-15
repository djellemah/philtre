# Philtre

It's the [Sequel](http://sequel.jeremyevans.net) equivalent for Ransack, Metasearch, Searchlogic. If
this doesn't make you fall in love, I don't know what will :-p

## Installation

Add this line to your application's Gemfile:

    gem 'philtre'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install philtre

## Usage

Parse the predicates on the end of field names, and round-trip the
search fields between incoming params, controller and views.

So, using a fairly standard rails-style parameter hash:

``` ruby
  filter_parameters = {
    birth_year: ['2012', '2011'],
    title_like: 'bar',
    order: ['title', 'name_asc', 'birth_year_desc'],
  }

  philtre = Philtre::Filter.new( filter_parameters ).apply( Personage.dataset ).sql
```

should result in (formatting added here for clarity)

``` SQL
  SELECT *
  FROM "personages"
  WHERE
    (("birth_year" IN ('2012', '2011'))
    AND
    ("title" ~* 'bar'))
  ORDER BY ("title" ASC, "name" ASC, "date" DESC)
```

Your form would look like this:
TODO verify this

``` haml
.filter
  = form_for philtre.for_form, url: params.slice(:controller,:action), method: 'get' do |f|
    = f.hidden_field :order
    = f.text_field :title_like, placeholder: 'Fancy Title'
    = f.select :year, (Date.today.year-90 .. Date.today.year).map( &:to_s), include_blank: 'Year', multi: true
    = f.submit 'Filter', name: nil, class: 'btn'
```

## Contributing

1. Fork it ( http://github.com/djellemah/philtre/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
