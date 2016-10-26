require "codeclimate-test-reporter"
CodeClimate::TestReporter.start
require "sqlite3"
require "active_record"
require "sequel"
require "graphql"
require "benchmark"
require "minitest/autorun"
require "minitest/focus"
require "minitest/reporters"
Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new(color: true)

Minitest::Spec.make_my_diffs_pretty!

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new


DEFAULT_EXEC_STRATEGY = ENV["GRAPHQL_EXEC_STRATEGY"] == "serial" ? GraphQL::Query::SerialExecution : GraphQL::Execution::DeferredExecution
puts "Default execution strategy: #{DEFAULT_EXEC_STRATEGY.name}"

# # Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

def star_wars_query(string, variables={})
  GraphQL::Query.new(StarWarsSchema, string, variables: variables).result
end
