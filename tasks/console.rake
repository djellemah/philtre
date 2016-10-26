desc "pry with libs"
task :console do
  ARGV.shift()
  ENV['RUBYLIB'] ||= ''
  ENV['RUBYLIB'] += ":#{File.expand_path('.')}/lib/philtre"
  exec "pry -r sequel -r philtre -I ./lib -I ."
end

task :pry => :console
task :irb => :pry
