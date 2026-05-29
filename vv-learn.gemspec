# frozen_string_literal: true

require_relative "lib/vv/learn/version"

Gem::Specification.new do |spec|
  spec.name        = "vv-learn"
  spec.version     = Vv::Learn::VERSION
  spec.authors     = ["MagenticMarket contributors"]
  spec.email       = ["substrate@magenticmarket.ai"]

  spec.summary     = "The autonomous, contract-first improvement loop over recorded substrate state."
  spec.description = <<~DESC.strip
    `vv-learn` is the LLM overseer that improves the deterministic
    substrate below. It runs autonomously over recorded `vv-process`
    runs, `vv-decision` aggregates, and `vv-memory` Bronze/Silver
    state — and authors TURNs back through the same rules a human
    curator follows. The LLM is the *author* of the proposal; an
    authorized human is the *committer*. vv-learn earns no
    privileges the human doesn't have.

    v0.1.0 ships the minimum viable round-trip: a
    `Vv::Learn::Program` DSL (`requires:` / `ensures:` /
    `shape.prohibited:`), the `Vv::Learn.run!` entrypoint, a
    `Vv::Learn::Run` AR aggregate root, a model dispatcher that
    wraps the caller's `ctx.sample`, and a hard-refusal pre-flight
    that fails the program **before any token is spent** if a
    `prohibited:` invariant would be violated. The
    `Vv::Learn::Reconciliation` typed surface, `strategies do ... end`
    adaptation guidance, Press-style sub-program recursion,
    `replay!`, the `vv-visualize` review UI integration, and the
    `vv-process` cadence binding wait until 0.2.0+. See
    `docs/plans/PLAN_0_1_0.md`.

    Status: pre-v0.1.0 — path-vendored under the MagenticMarket
    substrate.
  DESC

  spec.homepage    = "https://github.com/laquereric/magentic-market-ai"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["allowed_push_host"] = "https://rubygems.org" if Gem::Version.new(spec.version.to_s) >= Gem::Version.new("1.0.0")
  spec.metadata["source_code_uri"]   = "https://github.com/laquereric/magentic-market-ai/tree/main/vendor/vv-learn"
  spec.metadata["changelog_uri"]     = "https://github.com/laquereric/magentic-market-ai/tree/main/vendor/vv-learn/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*.rb",
    "app/**/*.rb",
    "db/migrate/*.rb",
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "VERSION",
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord",    ">= 8.0"
  spec.add_dependency "activesupport",   ">= 8.0"
  spec.add_dependency "railties",        ">= 8.0"

  # PLAN_0_1_0 PREREQ-A + PREREQ-B — the SHACL-validation facade
  # (`Vv::Memory::Scoped#shacl_validate`) + the `Vv::Memory::TurnEpisode`
  # typed subclass are the integration points. The boot-time
  # `MissingDependency` guard in Engine checks both constants/methods
  # are present — the authoritative readiness signal. The exact
  # version pin is finalized once PREREQ-A/B ship in vv-memory
  # (likely 0.3.0); declared loosely here.
  spec.add_dependency "vv-memory",       ">= 0.2.0"

  # PLAN_0_1_0 PREREQ-C — the nested consider-then-decide loop in
  # vv-decision 0.2.0. One `Vv::Learn::Run` maps to one
  # `Vv::Decision::Decision` holding N `consider` events before a
  # terminal `decide!` ("file this TURN"). vv-learn does not start
  # Phase C until vv-decision 0.2.0 lands.
  spec.add_dependency "vv-decision",     ">= 0.1.0"

  # Cr-reconciliation dispatch — every agent task vv-learn authors is
  # dispatched through the vv-agent BYO-provider façade
  # (`Vv::Agent::Task.run!`), never a hardwired model SDK. The live
  # dispatch is guarded behind a `RuntimeNotReady` check until
  # vv-agent's Task runtime (Phase D) lands; the contract + validation
  # surfaces work without it.
  spec.add_dependency "vv-agent",        ">= 0.1.0"

  # PLAN_0_1_0 §"v0.1.0 contract additions" — no-direct-vv-graph-
  # dependency layering rule. SHACL pre-validation reaches vv-graph
  # only through `Vv::Memory::Scoped#shacl_validate`. Direct
  # `vv-graph` imports under `lib/vv/learn/` are a layering
  # violation. vv-graph is pulled transitively via vv-memory; no
  # gemspec dependency declared.

  spec.add_development_dependency "rspec",   "~> 3.13"
  spec.add_development_dependency "rake",    "~> 13.0"
  spec.add_development_dependency "sqlite3", "~> 2.4"
end
