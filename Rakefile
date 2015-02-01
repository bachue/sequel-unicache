require "bundler/gem_tasks"

desc 'Run all test cases'
task :test do
  root = File.expand_path __dir__
  specs = "#{root}/spec"
  spec_helper = root + '/spec/spec_helper'
  exec 'bundle', 'exec', 'rspec', '-f', 'd',
       '-I', root, '-r', spec_helper, '-b', '-c', specs
end

task default: [:test]

