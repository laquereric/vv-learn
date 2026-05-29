# Changelog

## Unreleased

- **CR-reconciliation improvement loop** (`Vv::Learn::CrReconciliation`).
  Reconciling each vendor submodule's `CONSUMER_REQUIREMENT_*` files
  against the substrate's plans is LLM-authored improvement work — it
  moves here from the MM superproject's `scripts/cr-reconcile-sweep.rb`
  bootstrap. Ships the `CrReconciliationProgram` contract (prohibits
  editing outside CR files, code changes, MM-boundary commits, and
  force-pushing over a newer remote), the typed `Target`, input
  validation, and the instruction builder as pure-Ruby surfaces.
  `.open(...)` dispatches one agent task per target **through vv-agent**
  (`Vv::Agent::Task.run!`, BYO-provider) — never a hardwired model —
  and raises `RuntimeNotReady` until that runtime lands, mirroring
  `Reconciliation.open`. Gemspec gains `vv-agent >= 0.1.0`.

## 0.1.0 — (unreleased)

First shippable release. Stands up the **autonomous,
contract-first improvement loop** over recorded substrate state.
vv-learn is the LLM overseer that improves the deterministic
substrate below; it authors TURNs against recorded state and
files them back through the same rules a human curator follows.
The LLM is the *author* of the proposal; an authorized human is
the *committer*.

See [docs/plans/PLAN_0_1_0.md](docs/plans/PLAN_0_1_0.md) for the
architectural sketch and the per-phase exit criteria this release
satisfies.

- **Phase A — gem skeleton + Engine.** `vv-learn.gemspec` pins
  `vv-memory >= 0.2.0` (PREREQ-A + PREREQ-B: the SHACL
  pre-validation facade `Vv::Memory::Scoped#shacl_validate` and
  the `Vv::Memory::TurnEpisode` typed subclass) + `vv-decision
  >= 0.1.0` (tightens to 0.2.0 once PREREQ-C ships the
  nested-consider loop) + `activerecord / railties >= 8.0`. **No
  direct `vv-graph` dependency** — the SHACL call reaches
  vv-graph only through vv-memory's facade. `lib/vv/learn.rb` is
  the top-level entry. `Vv::Learn::Engine` isolates the
  namespace and registers an `after_initialize` guard that
  raises `Vv::Learn::Errors::MissingDependency` if any of
  `Vv::Memory::Scoped#shacl_validate`, `Vv::Memory::TurnEpisode`,
  or `Vv::Decision.deliberate` is undefined. Seven pinned error
  classes: `MissingDependency`, `ContractFailed`,
  `ProhibitedAction`, `ContractFrozen`,
  `StrategiesNotYetSupported`, `ReplayNotYetSupported`,
  `NoTurnFiled`.
