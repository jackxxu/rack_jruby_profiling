raise 'specs can only be run with JRuby' unless Object.const_defined?('Java')

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'rack_jruby_profiling'
require 'spec'
require 'spec/autorun'
require 'rack/test'

Spec::Runner.configure do |config|

end
