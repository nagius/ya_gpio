require 'rspec/core/rake_task'
require 'bundler/gem_tasks'
require 'yard'

YARD::Rake::YardocTask.new do |t|
 t.files   = ['lib/*.rb', 'README.md']   # optional
 t.stats_options = ['--list-undoc']         # optional
end

RSpec::Core::RakeTask.new(:spec)

