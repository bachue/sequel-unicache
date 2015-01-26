require "bundler/gem_tasks"

task :test do
  root = File.expand_path __dir__
  specs = Dir["#{root}/spec/*_spec.rb"]
  spec_helper = root + '/spec/spec_helper'
  exec 'bundle', 'exec', 'rspec', '-f', 'd',
       '-I', root, '-r', spec_helper, '-b', '-c', *specs
end

