# PLAN_0_1_0 — `vv-learn` first shippable release

> *Stands up the `vv-learn` gem as the **autonomous,
> contract-first improvement loop** that runs over recorded
> substrate state and proposes changes back through the same TURN
> rules a human curator follows. v0.1.0 ships the **minimum
> viable round-trip** — a `Vv::Learn::Program` DSL (`requires:`
> / `ensures:` / `shape.prohibited:`), the `Vv::Learn.run!`
> entrypoint, a `Vv::Learn::Run` AR aggregate root, a model
> dispatcher that wraps the caller's `ctx.sample`, and a
> hard-refusal pre-flight that fails the program **before any
> token is spent** if a `prohibited:` invariant would be
> violated. The `Vv::Learn::Reconciliation` typed surface, the
> `strategies do ... end` adaptation DSL, Press-style
> sub-program recursion, `replay!`, the `vv-visualize` review
> UI integration, and the `vv-process` cadence binding wait
> until v0.2.0+ once at least one consumer (`mm-server`) drives
> requirements. The bet: get the `run! → consider → file →
> record` round-trip right first; defer the typed-TURN-authoring
> surfaces and the operator-facing review wiring until the
> contract grammar has shaken out against real evidence
> slices.*

## Anchors

| Anchor | Where | Role |
|---|---|---|
| `../../README.md` | this gem | The architectural finding that motivates the gem. Contract-first improvement, Press's *model-as-CPU* posture, TURN-mediated commit gate, bring-your-own-LLM. The DSL sketch in §"Sketch of the surface" is the source for the v0.1.0 surface. |
| `../../../../docs/research/Press.md` | parent repo | The openprose/press pattern this gem's UX is modelled on. The `requires:` / `ensures:` / `strategies:` / `shape.prohibited:` grammar comes from there; the **departures** (commit gate, TURN authoring, hard-refusal shapes) are spelled out in the README and frozen in this plan. |
| `../../../vv-memory/docs/plans/PLAN_0_2_0.md` (or later) | sibling — **PREREQ-A & PREREQ-B** | The Conformer + Bronze episode substrate. v0.1.0 of *this* gem depends on **two new vv-memory facades** that PREREQ-A and PREREQ-B land first: `Vv::Memory::Scoped#shacl_validate(diff)` (delegates into vv-graph) and `Vv::Memory::TurnEpisode < Vv::Memory::Episode` (typed subclass with `author_kind`, `contract_id`, `evidence_slice_ref`, `shacl_pre_validation_ok`, `committer_ref` columns). |
| `../../../vv-decision/docs/plans/PLAN_0_2_0.md` | sibling — **PREREQ-C** | The nested consider-then-decide loop. v0.1.0 of *this* gem maps one `Vv::Learn::Run` to one `Vv::Decision::Decision` holding N `consider` events before a terminal `decide!` ("file this TURN"). vv-decision 0.2.0 is the gating extension; vv-learn does not start Phase C until it lands. |
| `../../../vv-graph/CONSUMER_REQUIREMENT_VV.md` | sibling (transitive) | The graph + SHACL layer. vv-learn has **no direct dependency** on vv-graph; the SHACL pre-validation reaches vv-graph only through PREREQ-A's facade. Pinned layering rule. |
| `../../../../docs/architecture/principles/grammar-and-llm-boundary.md` | parent repo | The layer-4 "LLM residual" stance: vv-learn is exactly where the substrate spends model tokens, run on cadence rather than in the hot path. This plan honours that boundary by routing every model call through `Vv::Decision` and refusing token spend on programs whose `shape.prohibited:` would fail. |
| `../../../../docs/architecture/principles/tesseron.md` | parent repo | The intent-layer doctrine. The README's §"Why this is a separate gem (vs. a Tesseron action)" — autonomous, model-driven, multi-step contracts need their own grammar. Pinned: vv-learn is **not** a Tesseron action. |

## Current state baseline (2026-05-25)

`vendor/vv-learn/` contains only `README.md` (the long-form
architectural description). No gem skeleton, no `Gemfile`, no
specs, no Engine, no `VERSION`. v0.1.0 is a greenfield build.

The substrate (`server/`) currently has **no autonomous-
improvement loop** at all. Improvement work today is
human-curator-driven: a person opens a TURN by hand through
the operator surfaces, walks the evidence themselves, drafts
the unambiguous description, runs SHACL pre-validation as a
manual step, and publishes through the existing process
runner. Nothing in the substrate authors a TURN
autonomously. v0.1.0 of *this* gem is the surface that makes
the autonomous-author role exist — without giving it the
committer privilege.

The vv-memory layer emits TURN-shaped Bronze episodes today
**without** a typed subclass — human curators record TURNs as
plain `Vv::Memory::Episode` rows with operator-chosen `kind:`
strings. PREREQ-B is the cross-gem change that introduces
`Vv::Memory::TurnEpisode` as the canonical home for *both*
human-curator and vv-learn TURN emissions; per the no-
backwards-compat rule, the existing untyped emissions get
migrated, not double-read.

The vv-decision layer (0.1.0) supports one `consider` and one
`decide!` per `deliberate(...)` block. vv-learn needs N
`consider` calls per Run (one per option the model weighed)
before the terminal `decide!` ("file TURN T"); that requires
the loop semantics shipping in vv-decision 0.2.0 (PREREQ-C).

The README's open questions on the Press-UX adaptation are
answered by this plan's frozen contract additions table
(§"v0.1.0 contract additions"). The `Vv::Learn::Reconciliation`
typed surface — the README's most architecturally distinctive
piece — is **deferred to v0.2.0** because (a) it requires the
nested-perspectives shape, which is not yet exercised against
real evidence, and (b) v0.1.0's plain `Program` already
exercises the contract grammar and the TURN-filing path; the
reconciliation surface is a *specialization*, not a separate
mechanism.

## Architectural shape (frozen at v0.1.0)

```
                                              ┌──────────────────────────┐
                  ┌─── run!(Program, scope:) ─→│ Vv::Learn.run!           │
   improvement   │                              └────────────┬─────────────┘
   cadence       │                                           │
                 │   ┌───────────────────────────────────────┼───────────────────────────────────────┐
                 │   ▼                                       ▼                                       ▼
                 │  ┌────────────────────────────┐  ┌────────────────────────────┐  ┌────────────────────────────┐
                 │  │ Program.compile            │  │ pre-flight                 │  │ open Vv::Decision         │
                 │  │   freeze contract:         │  │   for each prohibited:     │  │   .deliberate(context:)   │
                 │  │   requires / ensures /     │  │   ask vv-memory facade →   │  │   route every model call  │
                 │  │   prohibited               │  │   refuse if would violate  │  │   through ctx.consider    │
                 │  └─────────────┬──────────────┘  └─────────────┬──────────────┘  └─────────────┬──────────────┘
                 │                │                               │                               │
                 │                ▼                               ▼ (if refused, zero tokens)     ▼
                 │  ┌──────────────────────────────────────────────────────────────────────────────────────────┐
                 │  │ Bronze — one or more Vv::Memory::Episode rows per run!(...) call                         │
                 │  │   kind: "learn_run_started" / "learn_evidence_slice_read" / "learn_model_consulted"     │
                 │  │ + one Vv::Memory::TurnEpisode row per filed TURN (PREREQ-B typed subclass)              │
                 │  │     author_kind: :learn, contract_id: <Program identifier>,                              │
                 │  │     evidence_slice_ref: <evidence slice IRI>,                                            │
                 │  │     shacl_pre_validation_ok: true,                                                       │
                 │  │     committer_ref: nil   ← stays nil; vv-learn never commits                            │
                 │  │ + one Vv::Decision::Decision AR row (the reasoning aggregate; PREREQ-C semantics)       │
                 │  │     N consider() events (options the model weighed) + 1 decide!() (the TURN to file)    │
                 │  │ + one Vv::Learn::Run AR row (this gem's aggregate root)                                 │
                 │  │     program_id, scope, evidence_slice_ref, reasoning_trace_id (FK → Decision),         │
                 │  │     filed_turn_ids (FK array → TurnEpisode), contract_outcomes (per-ensures pass/fail) │
                 │  └────────────────────────────┬─────────────────────────────────────────────────────────────┘
                 │                               │
                 │                               ▼
                 │  ┌──────────────────────────────────────────────────────────────────────────────────────────┐
                 │  │ Silver — typed triples in the scope's named graph (via vv-memory Conformer at next       │
                 │  │ conform_now! tick — not in the hot path of run!)                                          │
                 │  │   <run:7> rdf:type vvlearn:Run ;                                                          │
                 │  │           vvlearn:program "Vv::Learn::OntologyTighteningProgram" ;                       │
                 │  │           vvlearn:contracts_satisfied true ;                                              │
                 │  │           vvlearn:filed_turn <turn:42> ;                                                  │
                 │  │           vvlearn:reasoned_through <decision:91> .                                        │
                 │  │   <turn:42> rdf:type vvmem:TurnEpisode ;                                                  │
                 │  │             vvmem:authored_by "vv-learn/v0.1.0/OntologyTighteningProgram" ;              │
                 │  │             vvmem:shacl_pre_validation_ok true ;                                          │
                 │  │             vvmem:committer "<unset>" .                                                   │
                 │  └──────────────────────────────────────────────────────────────────────────────────────────┘
                 │
   operator ←────┘   The operator reads <turn:42> in vv-visualize's ontology hub (deferred to v0.2.0),
   review            decides whether to commit, and publishes through a vv-process definition that
                     records the decision in vv-decision. vv-learn never holds the commit privilege.
```

## Scope

### Phase A — gem skeleton + Engine

Bundler layout under `vendor/vv-learn/`:

```
vv-learn/
├── vv-learn.gemspec
├── Gemfile
├── lib/
│   ├── vv/learn.rb                      # top-level entry; requires the rest
│   ├── vv/learn/version.rb              # VERSION = "0.1.0"
│   ├── vv/learn/engine.rb               # Rails::Engine, isolate_namespace Vv::Learn
│   ├── vv/learn/railtie.rb              # eager-load + dep checks (vv-memory, vv-decision)
│   ├── vv/learn/errors.rb               # MissingDependency, ProhibitedAction, ContractFailed, NoTurnFiled, …
│   ├── vv/learn/program.rb              # Phase B (DSL + compile)
│   ├── vv/learn/run.rb                  # Phase C (AR aggregate root)
│   ├── vv/learn/model_dispatcher.rb     # Phase D (BYO-LLM wrapper)
│   └── vv/learn/runtime.rb              # Phase C (the run! body — pre-flight + deliberate block)
├── app/
│   └── models/
│       └── vv/learn/run.rb              # canonical AR model
├── db/
│   └── migrate/
│       └── 20260601000001_create_vv_learn_runs.rb
├── spec/
│   ├── spec_helper.rb
│   ├── support/
│   │   ├── rails_app.rb                 # minimal in-process Rails app w/ AS + vv-memory + vv-decision
│   │   ├── fake_scope.rb                # FakeWorkspace AR fixture including Vv::Memory::Scoped
│   │   ├── fake_model.rb                # Spy model — tracks every .sample call; configurable canned responses
│   │   └── fake_shacl_facade.rb         # Stub Vv::Memory::Scoped#shacl_validate for refusal tests
│   └── vv/learn/
│       ├── program_spec.rb              # Phase B (DSL compile)
│       ├── hard_refusal_spec.rb         # Phase B′ (asserts zero model calls when prohibited)
│       ├── runtime_spec.rb              # Phase C (run! body — Bronze + TurnEpisode + Decision + Run rows)
│       ├── model_dispatcher_spec.rb     # Phase D (every call routes through ctx.consider)
│       └── round_trip_integration_spec.rb  # Phase E (acceptance signal)
├── bin/check                            # one-shot pre-release script
├── CHANGELOG.md
├── README.md                            # already present; Phase E expands Quickstart
├── CONSUMER_REQUIREMENT_MM.md           # Phase E
├── VERSION                              # 0.1.0
└── docs/
    └── plans/
        └── PLAN_0_1_0.md                # this file
```

#### Implementation
- `vv-learn.gemspec`:
  - `spec.required_ruby_version = ">= 3.4"`.
  - `spec.add_dependency "rails", ">= 8.1"`.
  - `spec.add_dependency "vv-memory", ">= <PREREQ-A/B target>"` — the
    SHACL facade + TurnEpisode subclass are the integration
    point. The exact pin is whatever version PREREQ-A and
    PREREQ-B ship in (likely vv-memory 0.3.0; finalized once
    PREREQ-A's PLAN is written).
  - `spec.add_dependency "vv-decision", ">= 0.2.0"` — the
    nested-consider/decide loop (PREREQ-C) is required.
  - **No** direct `vv-graph` dependency. The SHACL call reaches
    vv-graph only through `Vv::Memory::Scoped#shacl_validate`.
    Documented in §"Risks" — if a future caller needs deeper
    graph access, the dependency boundary changes via an
    explicit PLAN, not silently.
- `lib/vv/learn.rb` requires `version`, `errors`, `engine`
  (Engine lazy-loads the rest under Rails).
- `Engine`: `isolate_namespace Vv::Learn`;
  `config.eager_load_namespaces << Vv::Learn`.
- `Railtie` (in `engine.rb`): in `config.after_initialize`,
  verify all of:
  - `Vv::Memory::Scoped` constant is defined,
  - `Vv::Memory::Scoped.instance_method(:shacl_validate)` exists,
  - `Vv::Memory::TurnEpisode` constant is defined,
  - `Vv::Decision.deliberate` responds with the nested-consider
    loop (probed via `Vv::Decision::VERSION` ≥ `"0.2.0"`).

  Raise `Vv::Learn::Errors::MissingDependency` with verbatim
  "bundle vv-memory <pin>+ and vv-decision 0.2.0+ alongside
  vv-learn" message if any check fails.
- Spec scaffold mirrors `vv-decision`'s pattern — minimal
  in-process Rails app boots ActiveStorage, ActiveRecord (SQLite
  memory), both sibling engines' migrations, plus this gem's
  migration before each suite.

#### Exit criteria
- `bundle install` from `vendor/vv-learn/` resolves clean (with
  PREREQ-A/B/C landed in their respective sibling gems).
- `bundle exec rspec` runs (zero specs acceptable for Phase A;
  the harness must boot).
- `require "vv/learn"` in a host Rails app with the prerequisite
  vv-memory and vv-decision versions installed does **not**
  raise; with any prerequisite missing it raises
  `Vv::Learn::Errors::MissingDependency` naming the missing
  surface.
- `VERSION` file present, `Vv::Learn::VERSION == "0.1.0"`.

### Phase B — `Vv::Learn::Program` DSL

The Press-shaped contract grammar. The class-level DSL freezes
into a compiled, immutable contract struct. **The compiled
contract is the durable artifact**; the model is the CPU that
satisfies it.

```ruby
class Vv::Learn::OntologyTighteningProgram < Vv::Learn::Program
  requires :scope                       # required input
  requires :evidence_window, default: 30.days

  ensures  :turn_filed                  # at exit, a TurnEpisode FK exists on Run
  ensures  :no_unilateral_publish       # Run#filed_turn.committer_ref must be nil

  shape do
    prohibited :bypass_shacl_pre_validation
    prohibited :publish_without_committer
    prohibited :widen_gold_without_curator_evidence
  end
end
```

#### Implementation
- `Vv::Learn::Program` is a Ruby class with class-level DSL
  methods. Subclasses call `requires :sym` / `requires :sym,
  default: value` / `ensures :sym` / `shape { prohibited :sym }`
  at class-definition time.
- Each call appends to a class-level array; the first call to
  `.compile` freezes the arrays and returns a `Contract` struct:
  ```ruby
  Vv::Learn::Program::Contract = Struct.new(
    :program_class,
    :requires,        # [{name:, default:}]
    :ensures,         # [:sym, ...]
    :prohibited,      # [:sym, ...]
    keyword_init: true,
  ) do
    def freeze!
      requires.freeze; ensures.freeze; prohibited.freeze; freeze
    end
  end
  ```
- `Program.compile` is memoized. Calling `requires` / `ensures`
  / `prohibited` *after* `.compile` raises `ContractFrozen` —
  this is the no-backwards-compat invariant: contracts don't
  shift mid-run.
- The `strategies do ... end` block is **deliberately omitted in
  v0.1.0**. Per the README's §"What this gem deliberately leaves
  to other layers", strategies are adaptation guidance, not
  contract-bearing. v0.1.0's `Program` only carries the things
  the runtime *checks*. Defining `strategies` raises
  `StrategiesNotYetSupported`.

#### Exit criteria
- A subclass of `Vv::Learn::Program` with `requires`,
  `ensures`, and `prohibited` clauses compiles successfully.
- The compiled contract is frozen; modification raises.
- A program that calls `strategies` raises
  `StrategiesNotYetSupported` (refusal symbol pinned).
- `program_spec.rb` covers the round-trip.

### Phase B′ — hard-refusal pre-flight

The load-bearing invariant. `prohibited:` clauses are **not
guidance** — they are pre-flight checks that fail the program
before any token is spent.

#### Implementation
- For each `prohibited:` symbol, the runtime owns a checker:
  ```ruby
  module Vv::Learn::Refusals
    REGISTRY = {
      bypass_shacl_pre_validation: ->(scope, diff) {
        result = scope.shacl_validate(diff)   # PREREQ-A facade
        result.success?
      },
      publish_without_committer: ->(scope, turn) {
        turn.committer_ref.nil?              # vv-learn must never set it
      },
      widen_gold_without_curator_evidence: ->(scope, diff) {
        diff.touches_gold? ? diff.has_curator_evidence? : true
      },
    }.freeze
  end
  ```
- Pre-flight runs **before** `Vv::Decision.deliberate(...)` opens
  its block. If any check returns false, the runtime raises
  `Vv::Learn::Errors::ProhibitedAction` naming the failed
  refusal symbol. **The model dispatcher is never constructed.**
- The hard-refusal spec uses a spy model and asserts
  `spy.sample_count == 0` after a refused run.
- New refusal symbols added in 0.1.x are additive (additive-only
  invariant; refusal symbols are part of the v0.1.0 contract
  table below).

#### Exit criteria
- `hard_refusal_spec.rb` configures a fake `shacl_validate`
  facade that returns `Failure`. A program with `prohibited
  :bypass_shacl_pre_validation` raises `ProhibitedAction`
  **before any model call**; spy model asserts zero
  invocations.
- The error message names the failed refusal symbol verbatim.

### Phase C — `Vv::Learn::Run` aggregate + `Vv::Learn.run!`

The aggregate root. One row per `run!(...)` call. Mirrors
`Vv::Memory::Episode`'s polymorphic-scope shape so the
`vv_learn_runs` table joins cleanly on `(scope_type, scope_id)`.

#### Schema

```ruby
create_table :vv_learn_runs do |t|
  t.string  :program_class,           null: false   # "Vv::Learn::OntologyTighteningProgram"
  t.references :scope, polymorphic: true, null: false
  t.string  :evidence_slice_ref                     # IRI of the evidence slice consulted
  t.references :reasoning_trace, foreign_key: { to_table: :vv_decision_decisions } # PREREQ-C
  t.json    :filed_turn_ids,          null: false, default: []  # FKs into vv_memory_episodes
                                                                 # (typed via TurnEpisode STI)
  t.json    :contract_outcomes,       null: false, default: {}  # { turn_filed: :pass, ... }
  t.boolean :contracts_satisfied,     null: false, default: false
  t.string  :started_at_token                      # for replay (v0.2.0); recorded but unused in 0.1.0
  t.datetime :started_at,             null: false
  t.datetime :finished_at
  t.timestamps
end
add_index :vv_learn_runs, [:scope_type, :scope_id]
add_index :vv_learn_runs, :program_class
```

#### Implementation
- `Vv::Learn.run!(program_class, scope:, model:, **inputs)`:
  1. `contract = program_class.compile`.
  2. Validate `inputs` against `contract.requires` — missing
     required keys raise `Vv::Learn::Errors::ContractFailed`
     (with `phase: :inputs`).
  3. For each `contract.prohibited`, invoke the registered
     refusal checker. On failure, raise `ProhibitedAction`.
     **Zero model calls happen if pre-flight fails.**
  4. Wrap the rest in a DB transaction:
     - Open `Vv::Decision.deliberate(scope: scope, context:
       program_class.name)` block — that block receives a
       `ctx` whose `sample` / `consider` / `decide!` semantics
       are PREREQ-C.
     - Construct a `Vv::Learn::ModelDispatcher.new(model:,
       ctx:)`. Hand it to a `Vv::Learn::Runtime` instance that
       drives the program. The runtime is a thin object — it
       calls `dispatcher.sample(prompt:)` repeatedly to build
       the TURN; v0.1.0 does **not** prescribe what those
       prompts say (that's the program author's
       responsibility).
     - The runtime appends one or more `Vv::Memory::TurnEpisode`
       rows via `scope.record_turn_episode(...)` (PREREQ-B
       facade name; finalized in PREREQ-B's PLAN).
     - On block exit, `ctx.decide!(option: filed_turn_iri,
       because: "<the program's exit summary>")` records the
       terminal decision.
  5. After the deliberate block returns, evaluate each
     `contract.ensures` symbol against `Run` state. Each
     `ensures` symbol resolves to a checker (analogous to
     refusals registry):
     ```ruby
     module Vv::Learn::Ensurances
       REGISTRY = {
         turn_filed: ->(run) { run.filed_turn_ids.any? },
         no_unilateral_publish: ->(run) {
           run.filed_turns.all? { |t| t.committer_ref.nil? }
         },
       }.freeze
     end
     ```
     Outcomes are written into `contract_outcomes`;
     `contracts_satisfied` is the AND across all ensures.
  6. Persist `Vv::Learn::Run`. Return it.

- Failure modes inside the deliberate block (model raises, no
  TURN filed, ensures fails) all roll back the transaction
  **but the failure is itself recorded** as a Bronze episode
  (`kind: "learn_run_failed"`) committed in a *separate*
  transaction outside the rollback. This mirrors the
  vv-decision pattern of recording-the-attempt even when the
  attempt's effects are rolled back.

#### Exit criteria
- A happy-path `runtime_spec.rb` asserts:
  - One `Vv::Learn::Run` row written.
  - At least one `Vv::Memory::TurnEpisode` row written, with
    `author_kind: :learn`, `committer_ref: nil`,
    `shacl_pre_validation_ok: true`.
  - One `Vv::Decision::Decision` row written, with N
    `consider` events ≥ 1 and exactly one `decide!`.
  - `run.contracts_satisfied? == true`.
- A failure-path spec (model raises) asserts:
  - No `Vv::Learn::Run` row.
  - One `Vv::Memory::Episode` with `kind: "learn_run_failed"`.
  - No `Vv::Memory::TurnEpisode` row.

### Phase D — `Vv::Learn::ModelDispatcher` (BYO-LLM)

Thin wrapper. No bundled model, no credentials.

#### Implementation
```ruby
class Vv::Learn::ModelDispatcher
  def initialize(model:, ctx:)
    @model = model              # whatever the caller passed; substrate hands `ctx.sample`
    @ctx   = ctx                # the open Vv::Decision::DeliberationContext
  end

  def sample(prompt:, grounded_in: nil)
    completion = @model.sample(prompt: prompt)   # the BYO-LLM call
    @ctx.consider(
      option:        completion,
      grounded_in:   grounded_in || [],
      via_prompt:    prompt,                    # PREREQ-C adds via_prompt: keyword
    )
    completion
  end
end
```

#### Exit criteria
- `model_dispatcher_spec.rb` with a spy model asserts every
  `sample(...)` invocation produces exactly one
  `ctx.consider(...)` event.
- Removing the dispatcher (calling `model.sample` directly)
  results in zero `ctx.consider` events — i.e. the dispatcher
  is the **only** path that satisfies the recording invariant.
  Documented as a contract: *every model call inside `run!`
  goes through `dispatcher.sample`, never the bare model*.

### Phase E — round-trip integration spec, `bin/check`, docs

#### Implementation
- `round_trip_integration_spec.rb`:
  - Boots the in-process Rails app with vv-memory, vv-decision,
    and vv-learn engines loaded.
  - Defines a tiny `TestTighteningProgram < Vv::Learn::Program`
    with one `requires`, one `ensures :turn_filed`, and one
    `prohibited :bypass_shacl_pre_validation`.
  - Configures a fake `shacl_validate` returning `Success`.
  - Runs `Vv::Learn.run!(TestTighteningProgram, scope:
    workspace, model: FakeModel.new(canned: "file turn"))`.
  - Asserts the full round-trip: Bronze episodes + TurnEpisode +
    Decision aggregate + Run aggregate all present, with the
    expected FK linkage.
  - Triggers `scope.conform_now!` and asserts the Silver-side
    `vvlearn:Run` triple is emitted with `vvlearn:filed_turn`
    pointing at the TurnEpisode's IRI.

- `bin/check`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  bundle exec rspec
  bundle exec rubocop --parallel
  ```

- `README.md`: expand Quickstart with the v0.1.0 happy-path
  example. Cross-link this plan. Note that
  `Vv::Learn::Reconciliation`, `strategies`, sub-program
  recursion, `replay!`, and the vv-visualize wiring are 0.2.0+.

- `CONSUMER_REQUIREMENT_MM.md`: name the first `mm-server`
  consumer surface — likely a nightly cadence that runs one or
  two `Vv::Learn::Program` subclasses against the substrate's
  workspaces and lets the resulting TurnEpisodes accumulate in
  the operator queue.

- `CHANGELOG.md`: 0.1.0 heading with the contract additions
  table from §"v0.1.0 contract additions" below.

#### Exit criteria
- `bin/check` green.
- Round-trip spec green.
- README Quickstart runnable end-to-end (operator can paste it
  into a Rails console against the substrate and observe the
  effects).

## Out of scope for v0.1.0

- **`Vv::Learn::Reconciliation` typed surface.** The README's
  §"Sketch of the surface" shows the
  `Vv::Learn::Reconciliation.open(...)` call. Not in v0.1.0 —
  the SME-perspective reconciliation needs a typed
  `Perspective` value object, an explicit
  `describe_unambiguously:` discipline at the type level, and
  the resolution-strategy enum. Lands in v0.2.0 once v0.1.0's
  generic `Program` has shaken out the contract grammar against
  real evidence slices.

- **`strategies do ... end` adaptation DSL.** Press-style
  adaptive guidance (`on(:many_low_confidence_silver) { prefer
  :reconciliation_turn }`). Calling `strategies` in v0.1.0
  raises `StrategiesNotYetSupported`. Lands in v0.2.0.

- **Press-style sub-program recursion.** `press()`-equivalent
  fan-out across recorded runs (one sub-program per
  `Vv::Process::Run`, fan-in to a synthesizer). The README
  names this; v0.1.0 ships flat `Program` only. Lands in v0.2.0
  or later — needs the v0.1.0 contract grammar to be exercised
  first.

- **`Vv::Learn::Run#replay!`.** Re-deriving filed TURNs against
  the same evidence slice + the same contracts with a different
  model. The `started_at_token` column is recorded in v0.1.0 to
  support this — the implementation lands in v0.2.0.

- **`vv-visualize` review UI integration.** The operator-facing
  ontology hub that shows queued TurnEpisodes authored by
  vv-learn. vv-visualize's PLAN owns this; vv-learn 0.1.0
  emits the typed TurnEpisode rows and stops there.

- **`vv-process` cadence binding.** Improvement programs *can*
  be driven by a `vv-process` definition for scheduled
  cadence; v0.1.0 leaves cadence to the caller (operators may
  cron a one-liner `Vv::Learn.run!(...)` themselves, or call
  it from a custom job). The named `vv-process` integration
  lands in v0.2.0 once the cadence shape stabilizes.

- **Bundled `Program` subclasses.** v0.1.0 ships the base class
  + the contract grammar. The
  `Vv::Learn::OntologyTighteningProgram` example in the README
  is **illustrative**; it is not shipped as a concrete class
  in v0.1.0. First-party programs land alongside the first
  consumer-PR (`mm-server`).

- **Health Dashboard 5-dimension evidence-slice reader.** The
  README's §"What vv-learn does" item 1 lists this; v0.1.0
  leaves the evidence-slice construction to the program
  author (they pass `evidence_slice_ref: <iri>` into `run!`).
  The packaged reader lands in v0.2.0.

- **Multi-Run analytics.** "Across the last 30 days of Runs,
  which programs file the most TURNs that survive the
  committer?" — possible by querying the `vv_learn_runs`
  table directly in v0.1.0; not packaged as a facade method.

- **Publishing to rubygems.org.** Path-sourced under
  `vendor/vv-learn/` for the entire v0.x.x line.

## v0.1.0 contract additions (frozen at release)

| Surface | Shape | Mutability |
|---|---|---|
| `Vv::Learn.run!(program_class, scope:, model:, **inputs)` → `Vv::Learn::Run` | module method | **Pinned.** Additive kwargs allowed in 0.1.x; `model:` stays a freeform duck-typed object (must respond to `.sample(prompt:)`). |
| `Vv::Learn::Program` class-level DSL — `requires :sym, default:` / `ensures :sym` / `shape { prohibited :sym }` | macro DSL | **Pinned.** Calling `strategies` raises `StrategiesNotYetSupported` (refusal symbol pinned; additive when lifted). |
| `Vv::Learn::Program::Contract` struct (`program_class`, `requires`, `ensures`, `prohibited`) + `Program.compile` | value object | **Pinned column names.** Additive new struct members allowed in 0.1.x. |
| `Vv::Learn::Run` AR model + `vv_learn_runs` table | schema | **Pinned column names.** Additive new columns allowed in 0.1.x. |
| `Vv::Learn::Run#contracts_satisfied?` / `#turns_filed` / `#evidence_slice` / `#reasoning_trace` | instance methods | **Pinned.** `#turns_filed` returns the `Vv::Memory::TurnEpisode` collection; `#reasoning_trace` delegates to `Vv::Decision::Decision`. |
| `Vv::Learn::Run#replay!` | refusal | **Pinned refusal — raises `ReplayNotYetSupported` in 0.1.0** (additive when lifted in 0.2.0). |
| `Vv::Learn::ModelDispatcher#sample(prompt:, grounded_in: nil)` | instance method | **Pinned.** Every model call inside `run!` goes through this — bypass is a contract violation, not a runtime error (no policing). |
| `Vv::Learn::Refusals::REGISTRY` keys — `:bypass_shacl_pre_validation`, `:publish_without_committer`, `:widen_gold_without_curator_evidence` | refusal symbols | **Pinned for the v0.x.x line.** Additive new symbols allowed in 0.1.x. |
| `Vv::Learn::Ensurances::REGISTRY` keys — `:turn_filed`, `:no_unilateral_publish` | ensures symbols | **Pinned for the v0.x.x line.** Additive new symbols allowed in 0.1.x. |
| Bronze episode `kind:` strings — `learn_run_started`, `learn_evidence_slice_read`, `learn_model_consulted`, `learn_run_failed` | convention | **Pinned.** Operators must not use these `kind:` strings for unrelated purposes. Exposed as `Vv::Learn::EPISODE_KINDS`. |
| `vvlearn:` namespace IRI prefix (`urn:vv-learn:annotation:`) | convention | **Pinned for the v0.x.x line.** |
| `Vv::Learn::Errors::MissingDependency` / `ProhibitedAction` / `ContractFailed` / `ContractFrozen` / `StrategiesNotYetSupported` / `ReplayNotYetSupported` / `NoTurnFiled` | exception classes | **Pinned class names.** `NoTurnFiled` is defined but not raised by v0.1.0's `run!` — operators may raise it themselves when their program is expected to file a TURN but didn't. |
| `Vv::Learn.run!` transaction shape — pre-flight outside, deliberate+TurnEpisode+Run inside one transaction, `learn_run_failed` Bronze episode in a separate transaction on failure | invariant | **Pinned.** Tightening of the transaction shape (e.g. splitting the inner transaction into pre/post-model phases) requires a new PLAN. |
| No-direct-vv-graph-dependency layering rule | invariant | **Pinned for the v0.x.x line.** SHACL pre-validation reaches vv-graph only through `Vv::Memory::Scoped#shacl_validate`. Direct vv-graph imports in `vv-learn/` are a layering violation. |

No structured-envelope `{ ok:, reason:, because: }` surface in
v0.1.0 — the gem composes Active Record exceptions for
persistence, vv-decision's surfaces for the reasoning loop, and
Ruby exceptions for its own contract violations. The unified
envelope surface waits until the analytical facades land in
v0.2.0+ (mirrors vv-decision's stance).

## Risks

| Risk | Mitigation |
|---|---|
| **PREREQ-A (vv-memory SHACL facade) slips.** vv-learn 0.1.0 cannot ship without `Vv::Memory::Scoped#shacl_validate`. | Phase A's `MissingDependency` guard checks the method exists. Sequence vv-learn 0.1.0 *after* the vv-memory PLAN that lands PREREQ-A. If PREREQ-A's design shifts (e.g. method name, return shape), Phase B′'s refusal checker is the only place that needs to track it. |
| **PREREQ-B (vv-memory TurnEpisode subclass) is the long pole.** It touches both human-curator TURN paths and vv-learn's filing path. The sweep of existing untyped emissions could surface unexpected call sites. | Run the human-curator audit (grep for `Vv::Memory::Episode.create*` + `record_episode(kind: "turn_*")`) *before* the PREREQ-B PLAN is written, not before this gem starts Phase A. The audit's findings shape PREREQ-B's migration; this gem's only contract is on the *typed* surface, which is stable regardless of what the migration looks like. |
| **PREREQ-C (vv-decision 0.2.0) might not land nested-consider semantics in the shape vv-learn assumes.** | vv-learn Phase A's guard checks `Vv::Decision::VERSION ≥ "0.2.0"`. If vv-decision 0.2.0's `consider` semantics differ from this plan's sketch, Phase C's spec catches it. Recovery: amend this plan and re-pin. No fallback to a per-call-Decision shape — per the no-backwards-compat rule, we pin to the PREREQ-C shape or we don't ship. |
| **The hard-refusal symbols are too coarse.** `:bypass_shacl_pre_validation` is one bit; real SHACL diffs might want a richer refusal vocabulary (which shape, which violation kind). | v0.1.0 pins coarse symbols intentionally — they are the contract's grammar, not a violation report. The richer detail lives in the `Vv::Learn::Errors::ProhibitedAction` exception's message + `cause:` chain (the underlying SHACL failure detail). Operators dashboarding refusals get the symbol; operators debugging a specific refusal walk the cause chain. |
| **Operators conflate `ensures` symbols with `prohibited` symbols.** Both are symbol-keyed registries; they look the same in casual reading. | Documented as **timing**: `prohibited` runs pre-flight (before any model call); `ensures` runs at exit. The error messages and the contract table call this out. The registries live in separate modules (`Refusals` vs. `Ensurances`) to make grep distinct. |
| **`Run#filed_turn_ids` as a JSON array (vs. a join table) makes per-turn queries awkward.** | Acceptable for v0.1.0 — most queries are per-Run, not per-Turn-back-to-Run. The TurnEpisode → Run back-link lives on the TurnEpisode side as `evidence_slice_ref` + `contract_id` (PREREQ-B). If per-Turn-to-Run queries become common in 0.2.0, introduce a `vv_learn_run_turns` join table (additive). |
| **A program's prompts are unconstrained in v0.1.0.** The runtime doesn't prescribe what `dispatcher.sample(prompt:)` says. An operator could ship a `Program` subclass whose prompts directly ask the model to violate the substrate's policies, and only the *output* gets caught by `shape.prohibited`. | Intentional. The Press posture is *contracts are the durable artifact, the model is the CPU*. Operators are free to write any prompts they like; the contract grammar enforces the **shape of the output**, not the **content of the request**. Documented in §"What this gem deliberately leaves to other layers". |
| **No `replay!` in v0.1.0 means a Run is non-reproducible.** Operators can't re-derive the same TURN with a newer model. | The `started_at_token` column is recorded in v0.1.0 so `replay!` lands additively in 0.2.0. v0.1.0 callers who need reproducibility today walk the Run's evidence slice manually + re-issue `run!` themselves; the result is a *new* Run, not a replayed one. Documented. |
| **The substrate's "bring-your-own-LLM" rule means vv-learn cannot enforce model-call rate limits, retry semantics, or budget controls.** | Pinned: vv-learn is layering-neutral on the model. Any rate-limiting / retry / budget shaping lives in the caller's `model:` object (or in a wrapper they pass). vv-learn's responsibility ends at *every call is recorded through `ctx.consider`*. |
| **`vv-learn` tests need to boot vv-memory, vv-decision, AND vv-graph migrations** — heaviest spec harness in the substrate. | Mirror vv-decision's pattern. The boot cost is paid once per `before(:suite)`. Acceptable. |
| **Operator unregisters refusal symbols at runtime.** | `Vv::Learn::Refusals::REGISTRY` is `.freeze`d at boot. Attempts to mutate raise. Operators who want a different refusal vocabulary subclass `Vv::Learn::Program` with their own refusal registry (additive surface for 0.2.0; v0.1.0 ships the frozen registry only). |

## Acceptance signal

1. PREREQ-A, PREREQ-B, and PREREQ-C have landed in their
   respective sibling gems with their own passing specs.
2. vv-learn Phases A/B/B′/C/D/E land with passing specs;
   Phase E's `round_trip_integration_spec.rb` is green.
3. `bin/check` green against the canonical dev environment.
4. `CHANGELOG.md` `0.1.0` heading drops `(unreleased)`.
5. `VERSION` → `0.1.0`.
6. `README.md` Quickstart documents the `Vv::Learn.run!`
   entrypoint, the contract DSL, the hard-refusal pre-flight
   discipline, and the typed `Vv::Memory::TurnEpisode`
   emission. The Quickstart is runnable in a Rails console
   against the substrate.
7. `CONSUMER_REQUIREMENT_MM.md` notes the first `mm-server`
   consumer surface (the nightly cadence) + the reserved
   `kind:` strings + the reserved refusal/ensures symbols.
8. The substrate `Gemfile` adds `vv-learn` via path source; at
   least one `Vv::Learn::Program` subclass exists under
   `mm-server` and runs against a real workspace, filing at
   least one `Vv::Memory::TurnEpisode` that an operator can
   review in vv-visualize (operator review UI deferred to
   v0.2.0 — for v0.1.0 acceptance, "operator can see the row
   in the AR console" is sufficient). Tracked as the 0.1.1 /
   first-consumer-PR milestone if not landed concurrently
   with the tag.

## Cross-references

- `../../README.md` — this gem's README (the architectural
  finding + the surface sketch this plan freezes).
- `../../../../docs/research/Press.md` — the openprose/press
  pattern; the departures (commit gate, TURN authoring,
  hard-refusal shapes) are pinned in this plan.
- `../../../vv-memory/docs/plans/<PREREQ-A PLAN>` — the SHACL
  facade prerequisite.
- `../../../vv-memory/docs/plans/<PREREQ-B PLAN>` — the
  `Vv::Memory::TurnEpisode` typed subclass prerequisite.
- `../../../vv-decision/docs/plans/PLAN_0_2_0.md` — the
  nested-consider-then-decide prerequisite.
- `../../../vv-graph/CONSUMER_REQUIREMENT_VV.md` — the graph
  layer this gem reaches **only transitively** through
  vv-memory; the layering boundary is pinned.
- `../../../vv-visualize/README.md` — the operator review
  surface (TURN review UI lands in vv-visualize's PLAN, not
  here).
- `../../../vv-process/README.md` — the deterministic runtime
  (cadence binding lands in v0.2.0).
- `../../../../docs/architecture/principles/grammar-and-llm-boundary.md`
  — the layer-4 LLM-residual stance.
- `../../../../docs/architecture/principles/tesseron.md` — the
  intent-layer doctrine that vv-learn complements rather than
  collapses into.
