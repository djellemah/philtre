desc "pry with libs"
task :console do
  ARGV.shift()
  ENV['RUBYLIB'] ||= ''
  ENV['RUBYLIB'] += ":#{File.expand_path('.')}/lib/filter-sequel"
  exec "pry -r filter -r grinder -I ./lib -I ."
end

task :irb => :pry
task :pry => :console
