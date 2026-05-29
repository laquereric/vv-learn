# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Phase A — pure-Ruby contract specs (Program DSL + Refusals
# registry) don't need the Rails app boot. Phase C/E specs that
# exercise `Vv::Learn.run!` round-tripping through vv-memory and
# vv-decision will pull in the full `support/rails_app.rb`
# harness (deferred until Phase C — needs PREREQ-A/B/C to have
# landed in the sibling gems first).

require "vv/learn/version"
require "vv/learn/errors"
require "vv/learn/program"
require "vv/learn/refusals"
require "vv/learn/reconciliation"
require "vv/learn/cr_reconciliation"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end
end
