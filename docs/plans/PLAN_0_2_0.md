# PLAN_0_2_0 — `vv-learn` reconciliation, replay, cadence

> *Builds on the v0.1.0 round-trip with the **three load-bearing
> surfaces the README headlines** but PLAN_0_1_0 deliberately
> deferred: (1) `Vv::Learn::Reconciliation` — the typed
> SME-reconciliation TURN authoring surface with
> unambiguous-description discipline at the type level; (2)
> `Vv::Learn::Run#replay!` — re-deriving the same TURN against the
> same evidence slice with a different model; (3) the `vv-process`
> cadence binding — running improvement programs on a deterministic
> schedule. v0.2.0 also lifts the `:strategies` refusal and lands
> the first first-party `Program` subclass
> (`Vv::Learn::OntologyTighteningProgram` — the README's headline
> example, finally shipped). Press-style sub-program recursion, the
> Health Dashboard 5-dimension reader, and the `vv-visualize`
> review-UI wiring wait until v0.3.0+ once at least one consumer
> drives them. The bet: 0.1.0 proves the contract grammar against a
> generic Program; 0.2.0 proves it against the **two specializations
> the substrate actually needs** — Reconciliation (SME-resolution
> shape) and a real ontology-tightening program — and adds the
> schedule + replay machinery that promotes vv-learn from
> "interactive runner" to "autonomous improvement cadence".*

## Anchors

| Anchor | Where | Role |
|---|---|---|
| `PLAN_0_1_0.md` | this gem | The minimum viable round-trip. Pins the contract grammar (`requires:` / `ensures:` / `shape.prohibited:`), the `Run` AR aggregate, the `ModelDispatcher`, and the hard-refusal pre-flight. v0.2.0 builds *on* this surface; the v0.1.0 frozen contract additions remain pinned. |
| `../../README.md` §"Sketch of the surface" | this gem | The `Vv::Learn::Reconciliation.open(...)` call sketch is the source for Phase A. Two-perspective disagreement + `describe_unambiguously:` prose + `proposed_resolution:` enum — that's the v0.2.0 shape. |
| `../../README.md` §"The Press UX, adapted" | this gem | The `strategies do ... end` adaptation guidance is sourced from the openprose/press pattern. v0.2.0 lifts the `StrategiesNotYetSupported` refusal pinned in v0.1.0. |
| `../../../vv-process/README.md` + `docs/plans/*` | sibling — **PREREQ-D** | The deterministic process runtime. vv-learn 0.2.0 binds improvement programs to a `Vv::Process::Definition` for cadence. The bound program runs *inside* a `Vv::Process::Run`, which means `Vv::Learn::Run.process_run_id` becomes a real FK. Requires whatever vv-process version exposes the bind-an-improvement-program surface; PLAN named in PREREQ-D. |
| `../../../vv-memory/CONSUMER_REQUIREMENT_LN.md` (this repo's view of vv-memory) | sibling | The direct-path surface from v0.1.0. v0.2.0's `Reconciliation` adds a fourth `record_*` call site: `record_reconciliation_episode` (or, if the PLAN decides otherwise, an extension to `record_turn_episode`'s payload shape). PREREQ-B' captures the delta. |
| `../../../vv-decision/CONSUMER_REQUIREMENT_LN.md` (proposed) | sibling | The reasoning-loop surface from v0.1.0. v0.2.0's `replay!` calls `Vv::Decision.replay!(decision_id, model:)` — a vv-decision surface that doesn't exist yet (PREREQ-E). Lifts the deferred replay restriction by delegating. |
| `../../../../docs/research/Press.md` | parent repo | The `strategies:` adaptation DSL is sourced from here; v0.2.0 lifts the refusal but keeps the contract-bearing/advisory distinction explicit. |
| `[[project-rails-semantica-renamed]]` | memory | The graph layer is `vv-graph`, not `rails-semantica`. v0.2.0's references continue to flow through vv-memory's facade — the layering rule (pinned in PLAN_0_1_0) holds. |

## Current state baseline (2026-05-26)

`vendor/vv-learn/` carries the v0.1.0 surfaces shipped by
PLAN_0_1_0:

- `Vv::Learn::Program` DSL (`requires:` / `ensures:` /
  `shape { prohibited: }`) compiling to a frozen `Contract`.
- `Vv::Learn::Refusals::REGISTRY` (3 pinned symbols) +
  `Vv::Learn::Refusals.check!` pre-flight.
- `Vv::Learn::Errors` — 7 pinned exception classes including
  `StrategiesNotYetSupported` and `ReplayNotYetSupported` (both
  lifted by v0.2.0).
- `Vv::Learn::Engine` `after_initialize` guard checking
  PREREQ-A/B/C.
- Two pure-Ruby spec files (program + refusals), 20/20 green.

What v0.1.0 deferred and v0.2.0 picks up:

- **`Vv::Learn::Reconciliation`** is undefined. The README sketch
  has no Ruby class to back it. v0.2.0 Phase A is the first time
  the typed SME-reconciliation surface exists.
- **`strategies do ... end`** raises
  `StrategiesNotYetSupported` at class-definition time. v0.2.0
  Phase C lifts the refusal and lands the contract-grammar
  shape — but keeps the advisory/contract-bearing distinction
  (strategies do NOT participate in the
  `contracts_satisfied?` evaluation).
- **`Vv::Learn::Run#replay!`** raises `ReplayNotYetSupported`.
  The `started_at_token` column is recorded but unused. v0.2.0
  Phase B lifts the refusal by delegating to a (proposed)
  `Vv::Decision.replay!` surface.
- **`vv-process` binding**: improvement programs run interactively
  in v0.1.0 (operator calls `Vv::Learn.run!`); there is no
  cadence machinery. v0.2.0 Phase D binds programs to a
  `Vv::Process::Definition` so they run on schedule.
- **No first-party `Program` subclasses ship in v0.1.0.** The
  `OntologyTighteningProgram` sketched in the README is
  *illustrative*. v0.2.0 Phase E ships it as a real class.

v0.2.0 does NOT pick up sub-program recursion, the Health
Dashboard reader, or the `vv-visualize` review-UI wiring —
those wait until v0.3.0+ once at least one consumer
(`mm-server` cadence + operator dashboards) drives shape
requirements.

## Architectural shape (frozen at v0.2.0)

```
                            ┌──────────────────────────────────────────────────────────┐
                            │ vv-learn 0.2.0 — additive over 0.1.0                     │
                            │                                                          │
   ┌─── operator ad-hoc ────│── Vv::Learn.run!(Program, scope:, model:, **inputs)      │
   │   (v0.1.0 path)        │     unchanged — round-trip + hard-refusal pre-flight    │
   │                        │     contract grammar now ALSO recognizes strategies     │
   │                        │                                                          │
   ├─── cadence-driven  ────│── Vv::Process::Definition binds a Program (Phase D)     │
   │   (v0.2.0 path)        │     Vv::Learn::Run#process_run_id ← FK into vv-process  │
   │                        │     replay! across cadence-tick boundaries works        │
   │                        │                                                          │
   ├─── reconciliation  ────│── Vv::Learn::Reconciliation.open(scope:,                │
   │   (v0.2.0 path)        │       perspectives: [...],                              │
   │   typed TURN            │       describe_unambiguously: <<~PROSE,                │
   │   authoring             │       proposed_resolution: :widen_ontology_...) (Phase A) │
   │                        │       returns a Vv::Learn::Run with a single filed      │
   │                        │       Vv::Memory::TurnEpisode whose payload carries     │
   │                        │       the typed Perspective array + the prose          │
   │                        │                                                          │
   └─── replay         ─────│── Vv::Learn::Run#replay!(model: new_model) (Phase B)    │
                            │     re-derives the TURN against the same evidence slice │
                            │     with a different model. New Run row, NEW            │
                            │     TurnEpisode row, same contract; the prior Run's     │
                            │     row is unchanged.                                   │
                            └──────────────────────────────────────────────────────────┘

   Below — the v0.1.0 round-trip path is unchanged.
   Above — every new surface composes through v0.1.0's substrate; no v0.1.0 contract is broken.
```

## Scope

### Phase A — `Vv::Learn::Reconciliation`

The typed SME-reconciliation TURN authoring surface. The
README's most architecturally distinctive piece — v0.1.0
deliberately deferred it because (a) it requires the typed
`Perspective` shape and (b) it needs `describe_unambiguously:`
discipline at the type level.

#### Implementation

`lib/vv/learn/reconciliation.rb`:

```ruby
module Vv
  module Learn
    # The SME-reconciliation TURN authoring surface (PLAN_0_2_0 Phase A).
    # Reconciliation is a specialization of the generic Program
    # round-trip — same hard-refusal pre-flight, same TurnEpisode
    # emission, same contract evaluation — with two typing
    # constraints that the generic Program doesn't enforce:
    #
    # 1. Two or more `Perspective` value objects (typed actor +
    #    predicate + object + confidence), passed in `perspectives:`.
    # 2. An `describe_unambiguously:` prose string that satisfies
    #    a minimum-length and minimum-discrimination check (see
    #    `Vv::Learn::Reconciliation::UnambiguousDescriptionCheck`).
    #
    # The README sketches the surface; this class makes the
    # discipline machine-enforceable.
    module Reconciliation
      Perspective = Data.define(:actor, :predicate, :object, :confidence) do
        def initialize(actor:, predicate:, object:, confidence:)
          raise ArgumentError, "actor must be a Symbol" unless actor.is_a?(Symbol)
          raise ArgumentError, "confidence must be in 0.0..1.0" unless (0.0..1.0).cover?(confidence)
          super
        end
      end

      RESOLUTIONS = %i[
        widen_ontology_with_skos_alt_label
        prefer_higher_confidence
        defer_to_curator
        request_extractor_revision
      ].freeze

      module_function

      def open(scope:, perspectives:, describe_unambiguously:, proposed_resolution:, model:)
        validate_inputs!(perspectives, describe_unambiguously, proposed_resolution)
        Vv::Learn.run!(
          ReconciliationProgram,
          scope: scope,
          model: model,
          perspectives: perspectives,
          unambiguous_description: describe_unambiguously,
          proposed_resolution: proposed_resolution,
        )
      end
    end
  end
end
```

A small `Vv::Learn::Reconciliation::ReconciliationProgram <
Vv::Learn::Program` defines the contract:

```ruby
class ReconciliationProgram < Vv::Learn::Program
  requires :perspectives                              # [Perspective, ...]
  requires :unambiguous_description                   # String
  requires :proposed_resolution                       # Symbol ∈ RESOLUTIONS

  ensures :turn_filed
  ensures :no_unilateral_publish
  ensures :perspectives_named                          # NEW for v0.2.0
  ensures :description_discriminates                   # NEW for v0.2.0

  shape do
    prohibited :bypass_shacl_pre_validation
    prohibited :publish_without_committer
  end
end
```

Two new `ensures` symbols land in
`Vv::Learn::Ensurances::REGISTRY` (additive per the v0.1.0
contract):

- `:perspectives_named` — at least two distinct `Perspective`
  rows; each carries an `actor:` symbol that does not collide
  with another row's actor.
- `:description_discriminates` — the prose names at least one
  concrete substring from each perspective (operator-readable
  evidence that the description isn't generic boilerplate).
  v0.2.0's check is a simple "every actor symbol AND at least
  one object literal from each perspective appears in the
  prose" — coarse but catches the laziest failure mode.

The `Reconciliation` lifecycle reuses the v0.1.0 round-trip
verbatim: pre-flight, transaction, deliberate block, ensures
evaluation, persist Run. The typed perspectives and prose ride
in the `TurnEpisode#payload` JSON column (via vv-memory's
existing payload pathway — no PREREQ-B' needed if the payload
column already carries arbitrary JSON; if not, see "Risks"
below).

#### Exit criteria

- `Vv::Learn::Reconciliation.open(...)` returns a
  `Vv::Learn::Run` with `contracts_satisfied? == true` when
  given two well-formed perspectives + a discriminating
  description.
- `:perspectives_named` and `:description_discriminates` are
  registered in `Vv::Learn::Ensurances::REGISTRY` (frozen,
  additive over the v0.1.0 keys).
- `Perspective.new(...)` raises `ArgumentError` on
  malformed input (non-Symbol actor, confidence outside
  `[0, 1]`).
- `spec/vv/learn/reconciliation_spec.rb` covers happy path +
  each `ensures` failure mode + each `prohibited` refusal.

### Phase B — `Vv::Learn::Run#replay!`

The additive surface the `started_at_token` column was reserved
for in v0.1.0. v0.2.0 lifts the `ReplayNotYetSupported`
refusal by delegating to a proposed `Vv::Decision.replay!`
surface (PREREQ-E).

#### Implementation

```ruby
class Vv::Learn::Run
  def replay!(model:, contracts: :as_recorded)
    raise Vv::Learn::Errors::ReplayContractMismatch unless contracts == :as_recorded

    # Delegate the reasoning trace to vv-decision — same Decision
    # aggregate, new model. vv-decision returns the new Decision;
    # we author a new TurnEpisode against the same evidence_slice_ref
    # and persist a new Vv::Learn::Run (the original is immutable).
    new_decision = ::Vv::Decision.replay!(
      decision_id: reasoning_trace_id,
      model: model,
      started_at_token: started_at_token,  # the v0.1.0 reserved column
    )

    Vv::Learn::Runtime.replay_through!(
      original_run: self,
      new_decision: new_decision,
      model: model,
    )
  end
end
```

The `contracts: :as_recorded` keyword is pinned (v0.2.0 only
supports replaying against the originally-compiled contract;
re-deriving a TURN against a *different* contract version is a
v0.3.0+ ask — it's a separate research question).

#### Exit criteria

- `Vv::Learn::Run#replay!(model: stub_model)` returns a NEW
  `Vv::Learn::Run` row.
- The original Run's row is unchanged (immutable per the v0.1.0
  contract).
- The new Run shares the original's `evidence_slice_ref` and
  `program_class`; carries a NEW `reasoning_trace_id` (the new
  Decision row from vv-decision's replay) and a NEW
  `filed_turn_ids` array (the freshly-authored TurnEpisode).
- `replay!` with `contracts: :loosened` (or any other value)
  raises `ReplayContractMismatch`.
- `Vv::Learn::Errors::ReplayNotYetSupported` is removed from
  `errors.rb`. The v0.1.0 acceptance signal "replay! raises
  ReplayNotYetSupported" is replaced verbatim by "replay! returns
  a new Run" in the v0.2.0 contract table.

### Phase C — `strategies do ... end`

Lift the `StrategiesNotYetSupported` refusal. Strategies are
adaptation guidance — **advisory, not contract-bearing**. They
adjust which `consider` events the runtime takes, but they do
NOT participate in the `contracts_satisfied?` evaluation.

#### Implementation

Class-level DSL extension to `Vv::Learn::Program`:

```ruby
class Vv::Learn::Program
  class << self
    def strategies(&block)
      guard_unfrozen!(:strategies)
      raise ArgumentError, "strategies requires a block" unless block_given?

      StrategiesDsl.new(self).instance_eval(&block)
    end
  end

  class StrategiesDsl
    def initialize(program_class); @program_class = program_class; end

    def on(condition_symbol, &handler)
      raise ArgumentError, "strategies.on requires a block" unless block_given?
      @program_class.send(:_strategies)[condition_symbol] = handler
    end
  end
end
```

The runtime invokes `program.compile.strategies` after reading
the evidence slice. For each `on(:condition) { prefer :action }`
that matches, the runtime emits a `Vv::Memory::Episode` with
`kind: "learn_strategy_applied"` and adjusts the
`ModelDispatcher`'s prompt-construction policy accordingly.
**The model's output is still subject to the same
`shape.prohibited:` refusals** — strategies adjust *which
prompts get sent*, not *which outputs are accepted*.

The v0.1.0 `:strategies` refusal in `errors.rb` is removed.
The v0.1.0 acceptance signal "strategies raises
StrategiesNotYetSupported" is replaced by "strategies compiles
and influences the runtime's prompt-construction policy".

#### Exit criteria

- `Vv::Learn::Program` subclasses declaring `strategies do ... end`
  compile without raising.
- `Contract#strategies` returns the frozen handler map.
- A program that triggers `on(:many_low_confidence_silver)`
  emits one `learn_strategy_applied` Bronze row.
- Strategies do NOT appear in `Contract#ensures` — the advisory
  nature is enforced at the schema level (Contract struct does
  not gain a public `strategies` accessor that
  `Vv::Learn::Ensurances::REGISTRY` would dispatch through).

### Phase D — `vv-process` cadence binding

The promotion from "interactive runner" to "autonomous
improvement cadence". Improvement programs bind to a
`Vv::Process::Definition`; the process runtime invokes
`Vv::Learn.run!` on each tick.

#### Implementation

A new `Vv::Learn::Schedulable` module that `Vv::Learn::Program`
subclasses extend to declare cadence:

```ruby
class OntologyTighteningProgram < Vv::Learn::Program
  extend Vv::Learn::Schedulable

  schedule :nightly                          # symbol resolves to a vv-process cron
  scope_finder { |context| Workspace.active.where(...) }

  requires :scope
  ...
end
```

The `Vv::Learn::Engine` `after_initialize` block registers each
schedulable Program with vv-process's definition registry. When
the process tick fires, vv-process invokes
`Vv::Learn::Runtime.invoke_for_schedule!(program, context)`,
which:

1. Resolves the `scope_finder` to N scopes.
2. For each scope, runs `Vv::Learn.run!(program, scope:,
   model: context.model, **defaulted_inputs)`.
3. Each `Vv::Learn::Run` row carries `process_run_id` (NEW
   column for v0.2.0 — additive over the v0.1.0 schema).

PREREQ-D names the vv-process surface this binds against. If
vv-process doesn't expose a definition-registry surface at
v0.2.0-time, this phase ships behind a feature predicate:
`Vv::Learn.cadence_supported?` returns false; calling `schedule`
raises `CadenceNotYetSupported` (a new pinned refusal).

#### Exit criteria

- A `Vv::Learn::Program` subclass declaring `schedule :nightly`
  registers with vv-process at Engine boot.
- A simulated process tick produces N `Vv::Learn::Run` rows,
  each carrying `process_run_id`.
- The `process_run_id` column is added by a v0.2.0 migration
  (additive — the column is nullable so v0.1.0 rows remain
  valid).
- If PREREQ-D doesn't land,
  `Vv::Learn::Errors::CadenceNotYetSupported` is raised at
  Program-class-definition time (NOT at boot — operators
  discover the deferral at the place they declared the
  cadence).

### Phase E — first-party `Vv::Learn::OntologyTighteningProgram`

The README's headline example, shipped as a real class.
Demonstrates the full v0.2.0 surface composed.

#### Implementation

```ruby
module Vv::Learn
  class OntologyTighteningProgram < Program
    extend Schedulable
    schedule :weekly

    requires :scope
    requires :evidence_window, default: 30 * 86_400    # 30 days
    requires :model

    ensures :turn_filed
    ensures :no_unilateral_publish

    strategies do
      on(:many_low_confidence_silver) { prefer :reconciliation_turn }
      on(:shacl_violations_rising)    { prefer :shape_tightening_turn }
    end

    shape do
      prohibited :bypass_shacl_pre_validation
      prohibited :publish_without_committer
      prohibited :widen_gold_without_curator_evidence
    end

    scope_finder { Workspace.active }
  end
end
```

The implementation body (the actual prompt construction +
`dispatcher.sample` loop) lives in
`lib/vv/learn/ontology_tightening_program/runtime.rb` —
deliberately separate from the contract declaration so the
contract is the README-visible artifact and the runtime is the
implementation detail.

#### Exit criteria

- `Vv::Learn::OntologyTighteningProgram.compile` returns a
  frozen `Contract` carrying both `strategies` AND the v0.1.0
  contract clauses.
- Manually invoking `Vv::Learn.run!(OntologyTighteningProgram,
  scope: workspace, model: fake_model)` files a TurnEpisode
  AND emits at least one `learn_strategy_applied` Bronze row
  when the fake conditions trigger.
- The class is named in `CONSUMER_REQUIREMENT_MM.md` as the
  first first-party program the substrate (mm-server) is
  expected to bind to its nightly cadence.

### Phase F — round-trip integration spec + `bin/check`

#### Implementation

Extends `spec/vv/learn/round_trip_integration_spec.rb` (the
v0.1.0 acceptance spec) with v0.2.0 cases:

- A `Vv::Learn::Reconciliation.open(...)` round-trip asserts
  the typed Perspective payload appears on the TurnEpisode and
  the `:description_discriminates` ensure passes.
- A `Run#replay!` round-trip asserts a NEW Run row with the
  same `evidence_slice_ref` and a NEW `reasoning_trace_id`.
- A simulated cadence tick (with a stub
  `Vv::Process::Runtime`) produces a `Vv::Learn::Run` carrying
  `process_run_id`.
- A `OntologyTighteningProgram` happy-path runs end-to-end.

#### Exit criteria

- `bin/check` green.
- `CHANGELOG.md` `0.2.0` heading drops `(unreleased)`.
- `VERSION` → `0.2.0`.
- `README.md` Quickstart adds the Reconciliation snippet (the
  one already sketched in §"Sketch of the surface") and a
  one-paragraph note pointing operators at
  `OntologyTighteningProgram` as the first first-party
  improvement.
- `CONSUMER_REQUIREMENT_MM.md` updated with the cadence + the
  schedulable program registration the substrate is expected
  to consume.

## Out of scope for v0.2.0

- **Press-style sub-program recursion.** Fan-out across recorded
  `Vv::Process::Run`s with a synthesizer fan-in. The
  generic-Program round-trip + Reconciliation specialization
  exercises the contract grammar enough; recursion lands in
  v0.3.0 once a consumer (probably the Health Dashboard reader)
  drives the fan-in shape.
- **The Health Dashboard 5-dimension evidence-slice reader.**
  Depends on `Vv::Memory.recall(scope:, query:, depth:)` (the
  vv-memory PLAN_0.4.0 surface, not yet shipped). v0.2.0 keeps
  the `evidence_slice_ref:` keyword as a freeform IRI; the
  program author constructs the slice. The packaged reader is
  v0.3.0+.
- **`vv-visualize` review UI integration.** The operator-facing
  ontology hub that surfaces queued TurnEpisodes authored by
  vv-learn. vv-visualize owns this; v0.2.0 of *this* gem emits
  the typed TurnEpisode rows and stops there. The acceptance
  signal "operator can see the row in the AR console" from
  v0.1.0 remains the bar.
- **Multi-Run analytics.** "Across the last 30 days of Runs,
  which programs file the most TURNs that survive the
  committer?" — possible by querying `vv_learn_runs` directly;
  not packaged as a facade method in v0.2.0.
- **`Vv::Learn::Reconciliation` with > 2 perspectives.** The
  `Perspective` array supports N values structurally; the
  `:perspectives_named` ensures clause accepts any N ≥ 2.
  Three-or-more perspective reconciliation is *supported* but
  not specifically tested or documented in v0.2.0 — the
  acceptance signal targets the two-perspective case from the
  README.
- **Strategy adaptation guidance composing with refusals
  multiplicatively.** v0.2.0's strategies adjust prompts; they
  do NOT compose with `shape.prohibited:` in a richer way
  (e.g., a strategy that says "prefer reconciliation when SHACL
  pre-validation marginal"). Strategies that depend on refusal
  outcomes are a v0.3.0 design question.
- **Replay across contract versions.** v0.2.0's `replay!`
  accepts `contracts: :as_recorded` only. Re-deriving a TURN
  against an evolved contract is a v0.3.0+ ask requiring a
  contract-versioning vocabulary that doesn't exist yet.
- **Publishing to rubygems.org.** Still path-vendored.

## v0.2.0 contract additions (frozen at release)

| Surface | Shape | Mutability |
|---|---|---|
| `Vv::Learn::Reconciliation.open(scope:, perspectives:, describe_unambiguously:, proposed_resolution:, model:)` → `Vv::Learn::Run` | module method | **Pinned.** Additive kwargs allowed in 0.2.x. |
| `Vv::Learn::Reconciliation::Perspective` Data class — `actor`, `predicate`, `object`, `confidence` | value object | **Pinned column names.** Additive members allowed in 0.2.x; `confidence` validation pinned to `0.0..1.0`. |
| `Vv::Learn::Reconciliation::RESOLUTIONS` — `:widen_ontology_with_skos_alt_label`, `:prefer_higher_confidence`, `:defer_to_curator`, `:request_extractor_revision` | symbol enum | **Pinned for the v0.x.x line.** Additive symbols allowed in 0.2.x. |
| `Vv::Learn::Ensurances::REGISTRY` adds — `:perspectives_named`, `:description_discriminates` | ensures symbols | **Pinned for the v0.x.x line.** Additive over v0.1.0; no v0.1.0 key is removed. |
| `Vv::Learn::Run#replay!(model:, contracts: :as_recorded)` → `Vv::Learn::Run` | instance method | **Pinned.** `contracts:` accepts `:as_recorded` only in 0.2.0; other values raise `ReplayContractMismatch` (refusal symbol pinned — additive when lifted in 0.3.0). |
| `Vv::Learn::Errors::ReplayContractMismatch` | exception class | **Pinned class name.** |
| `Vv::Learn::Run#process_run_id` AR column (nullable FK into `vv_process_runs`) | schema | **Pinned column name.** Nullable so v0.1.0 rows remain valid. |
| `Vv::Learn::Program.strategies(&block)` + `StrategiesDsl#on(condition) { prefer :action }` | class-level DSL | **Pinned.** Strategies are advisory; they do NOT appear in `Contract#ensures` and do NOT influence `contracts_satisfied?`. |
| `Vv::Learn::Schedulable` module — `schedule :symbol`, `scope_finder { ... }` | mixin DSL | **Pinned.** `:nightly` / `:weekly` / `:hourly` symbols are pinned for the v0.x.x line; additive symbols allowed in 0.2.x. |
| `Vv::Learn::OntologyTighteningProgram` class | first-party program | **Pinned name + contract shape.** Implementation body in `ontology_tightening_program/runtime.rb` is NOT pinned and may evolve freely within the contract. |
| Bronze episode `kind:` adds — `learn_strategy_applied`, `learn_replay_started`, `learn_cadence_tick` | convention | **Pinned for the v0.x.x line.** Additive over v0.1.0's `EPISODE_KINDS`. |
| **Removed in v0.2.0:** `Vv::Learn::Errors::StrategiesNotYetSupported`, `Vv::Learn::Errors::ReplayNotYetSupported` | refusal removal | Per [[feedback-no-backwards-compat]] — these were *placeholders* for surfaces v0.2.0 fills; they are removed, not aliased. Callers that rescued either class get a `NameError` and must update — that's the intended signal. |

The unified `{ ok:, reason:, because: }` envelope surface
remains deferred (still mirrors vv-decision's stance). The v0.2.0
surfaces compose Active Record exceptions, vv-decision's
surfaces for the reasoning loop, vv-process's surfaces for
cadence, and Ruby exceptions for vv-learn's own contract
violations.

## Risks

| Risk | Mitigation |
|---|---|
| **PREREQ-D (vv-process binding surface) doesn't exist.** v0.2.0 Phase D depends on vv-process exposing a Program-registry hook. If vv-process's PLAN for this surface slips, Phase D ships behind `Vv::Learn::Errors::CadenceNotYetSupported` at Program-class-definition time. | Engine boot does NOT depend on PREREQ-D being present — the cadence surface is opt-in (operators who don't call `schedule` see no behaviour change). v0.2.0 can still ship without PREREQ-D landed; the contract table flags Cadence as conditional. The acceptance signal for Phase D is the simulated-tick spec, which uses a stub `Vv::Process::Runtime` and exercises the in-process registration. |
| **PREREQ-E (vv-decision replay surface) doesn't exist.** v0.2.0 Phase B's `replay!` delegates to `Vv::Decision.replay!`. If vv-decision's PLAN_0_2_0 (or 0_3_0) doesn't ship replay, Phase B's lifting of `ReplayNotYetSupported` is itself blocked. | Pinned the same way as PREREQ-D — `Vv::Learn::Run#replay!` checks `defined?(Vv::Decision.replay!)` and raises a new `Vv::Learn::Errors::ReplayBackendMissing` (NOT `ReplayNotYetSupported` — that one is removed regardless, to keep the v0.1.0 → v0.2.0 surface migration sweep-and-replace) if absent. The acceptance signal "replay! returns a new Run" is conditional on PREREQ-E. |
| **The `:description_discriminates` check is too weak.** "Every actor symbol AND at least one object literal from each perspective appears in the prose" is coarse — an operator can satisfy it with cargo-culted prose that names the symbols without genuinely discriminating. | Acknowledged. v0.2.0 ships the coarse check because the alternative is an LLM-judged discrimination check, which couples vv-learn's `ensures` evaluation to a model call — that's load-bearing wrong (refusals must be deterministic). The richer check is a v0.3.0 design question; one option is a SHACL-style cardinality check on the typed payload. Documented in §"Out of scope" → "Strategy adaptation guidance composing with refusals". |
| **Strategies adjust *prompts*, not *outputs* — operators may expect strategies to influence which TURN gets filed.** | Documented explicitly in PLAN_0_2_0 Phase C and the README v0.2.0 update. The advisory/contract-bearing distinction is the design — strategies that influence output shape would collapse the `shape.prohibited:` invariant. Operators who want output-shape adjustments file additional refusal symbols. |
| **`Vv::Memory::TurnEpisode#payload` JSON column may not exist (PREREQ-B' delta).** v0.1.0's PREREQ-B specified a fixed column set; Reconciliation's typed Perspective array + prose ride in a `payload` JSON column. If PREREQ-B didn't land a `payload` column, Reconciliation needs a v0.2.0 vv-memory addition. | Coordinated through `CONSUMER_REQUIREMENT_LN.md` in vv-memory. The B1 spec in that file already calls out `payload:` as a kwarg on `record_turn_episode`; assuming PREREQ-B implements it consistent with the spec, no additional vv-memory work needed. Drift signal flagged in §"Boundary items" of `CONSUMER_REQUIREMENT_LN.md` (item D3). |
| **`Vv::Learn::OntologyTighteningProgram`'s prompt body is unconstrained.** The README sketches what the program should do but doesn't pin prompt content. Different operators could produce wildly different prompt bodies for the same compiled contract. | Intentional — the prompt body is not a contract-bearing surface. The contract is what's pinned; the prompt body lives in `runtime.rb` and may evolve. This mirrors PLAN_0_1_0's stance: "the runtime doesn't prescribe what `dispatcher.sample(prompt:)` says". Operators wanting prompt-content discipline write their own subclass. |
| **Removing `StrategiesNotYetSupported` and `ReplayNotYetSupported` exception classes is a breaking change.** Any v0.1.0 consumer that rescued either gets a `NameError` after upgrading. | Per [[feedback-no-backwards-compat]] — sweep-and-replace, no aliasing. The breaking change is the intended migration signal. The v0.2.0 CHANGELOG names both classes in a top-level "Removed" section so consumers see the diff. |
| **Replay across cadence-tick boundaries may produce TURNs that immediately conflict with the operator's already-committed prior TURNs.** A nightly-cadence program that runs against the same workspace each night may file the same reconciliation TURN repeatedly. | v0.2.0 does NOT dedup. The `vv_learn_runs` table has a `program_class` + `scope` index; operators querying "did this program already file an open TURN for this scope this week" can dedup themselves. Auto-dedup is a v0.3.0 design question — it depends on what "the same TURN" means for the operator (same `evidence_slice_ref`? same `contract_id`? same prose?), which is consumer-shape, not core-substrate. |
| **The `Vv::Learn::Schedulable` registration runs at Engine `after_initialize` — order with vv-process's own boot is fragile.** | Mirror vv-decision's pattern (`DecisionExtractor` registration). The Engine guard already checks `defined?(::Vv::Process)`; if vv-process is in the bundle but not yet booted, the registration deferral happens through ActiveSupport's `on_load(:vv_process)` (or vv-process's equivalent — to be confirmed in PREREQ-D's spec). Documented as a drift signal in `CONSUMER_REQUIREMENT_LN.md` (or a new `CONSUMER_REQUIREMENT_LN.md` in `vv-process/`). |
| **A spec harness that boots vv-memory + vv-decision + vv-process + vv-learn migrations is approaching the boot-time ceiling.** | Mirror vv-decision's `before(:suite)` pattern. If suite startup time materially regresses, consider splitting `spec/vv/learn/cadence_*` into its own RSpec group with `:cadence` tag and skipping it when the env hints (`SKIP_CADENCE=1`). Not a v0.2.0 blocker. |

## Acceptance signal

1. PREREQ-A, PREREQ-B from PLAN_0_1_0 must remain landed
   (regression check during v0.2.0 release).
2. PREREQ-D (vv-process binding) and PREREQ-E (vv-decision
   replay) are EITHER landed in sibling gems with their own
   passing specs, OR vv-learn 0.2.0 ships the corresponding
   surfaces behind their conditional refusal classes
   (`CadenceNotYetSupported` / `ReplayBackendMissing`). The
   v0.2.0 release MUST NOT silently fall back — the refusal
   class is the operator-visible signal that the prerequisite
   isn't yet bundled.
3. vv-learn Phases A/B/C/D/E/F land with passing specs; Phase
   F's `round_trip_integration_spec.rb` covers each new
   surface (Reconciliation, replay!, strategies, cadence,
   OntologyTighteningProgram).
4. `bin/check` green against the canonical dev environment.
5. `CHANGELOG.md` `0.2.0` heading drops `(unreleased)`. The
   CHANGELOG includes a top-level **Removed** section naming
   `StrategiesNotYetSupported` and `ReplayNotYetSupported` —
   no backwards-compat aliasing per
   [[feedback-no-backwards-compat]].
6. `VERSION` → `0.2.0`.
7. `README.md` Quickstart expands to cover
   `Vv::Learn::Reconciliation.open(...)` (the README's existing
   sketch becomes runnable) and a paragraph pointing operators
   at `OntologyTighteningProgram` as the first first-party
   improvement. The "Status: pre-v0.1.0" banner is replaced
   with a "Status: 0.2.0" banner (or whatever the substrate's
   pre-release convention is at that point).
8. `CONSUMER_REQUIREMENT_MM.md` documents the substrate's
   binding: which workspaces the nightly cadence runs against,
   what fake/real models the substrate hands the dispatcher,
   and the operator-review TURN queue shape mm-server expects.
9. `CONSUMER_REQUIREMENT_LN.md` in `vv-memory/` and (new) in
   `vv-decision/` + `vv-process/` updated with v0.2.0's
   additions (the `payload:` kwarg confirmation, the `replay!`
   surface, the schedulable-registration hook).
10. The substrate's `Gemfile` consumes `vv-learn` 0.2.0 via
    path source; mm-server has at least one
    `Vv::Learn::Program` subclass extending `Schedulable`
    registered against vv-process and producing
    `Vv::Learn::Run` rows on each tick. (Tracked as the 0.2.1 /
    first-cadence-PR milestone if not landed concurrently
    with the tag.)

## Cross-references

- `PLAN_0_1_0.md` — the v0.1.0 minimum viable round-trip. v0.2.0
  is strictly additive; no v0.1.0 contract is broken.
- `../../README.md` — the architectural finding + the
  Reconciliation surface sketch.
- `../../../../docs/research/Press.md` — the `strategies:`
  adaptation guidance is sourced here; the
  contract-bearing/advisory split is the load-bearing
  departure.
- `../../../vv-process/docs/plans/<PREREQ-D PLAN>` — the
  cadence-binding prerequisite.
- `../../../vv-decision/docs/plans/<PREREQ-E PLAN>` — the
  `Vv::Decision.replay!` prerequisite.
- `../../../vv-memory/CONSUMER_REQUIREMENT_LN.md` — the direct
  vv-memory surface vv-learn consumes (carried over from
  v0.1.0; v0.2.0 adds the `payload:` confirmation for
  Reconciliation's typed Perspective array).
- `../../../vv-decision/CONSUMER_REQUIREMENT_LN.md` — the
  vv-decision surface vv-learn consumes (proposed in
  PLAN_0_1_0; v0.2.0 adds the `replay!` ask).
- `../../../vv-visualize/README.md` — the operator review
  surface that consumes vv-learn's TurnEpisodes. Wired up in
  v0.3.0+; v0.2.0 emits the rows and stops there.
- `../../../../docs/architecture/principles/grammar-and-llm-boundary.md`
  — the layer-4 LLM-residual stance. v0.2.0's cadence binding
  is the substrate's first scheduled-token-spend; the principle
  is honoured by the hard-refusal pre-flight + the
  `prohibited:` invariants holding regardless of cadence.
- `[[project-rails-semantica-renamed]]` — the graph layer is
  `vv-graph`. All v0.2.0 references continue to flow through
  vv-memory's facade.
