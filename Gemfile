# frozen_string_literal: true

source "https://rubygems.org"

# Path-vendored siblings. The hard dependencies are vv-memory
# (for `Scoped#shacl_validate` PREREQ-A + `TurnEpisode` PREREQ-B)
# and vv-decision (for the nested consider-then-decide loop
# PREREQ-C). vv-graph is reached only transitively through
# vv-memory's facade — pinned via path so Bundler resolves a
# single checkout across all four gems.
gem "vv-memory",   path: "../vv-memory"
gem "vv-decision", path: "../vv-decision"
gem "vv-graph",    path: "../vv-graph"

# Specify dependencies in vv-learn.gemspec.
gemspec
