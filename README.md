# vv-learn

**The LLM overseer that improves the deterministic substrate below.**
Where [`vv-graph`](../vv-graph) owns triples,
[`vv-memory`](../vv-memory) owns the medallion lifecycle,
[`vv-decision`](../vv-decision) owns the reasoning loop,
[`vv-process`](../vv-process) owns the deterministic step machinery,
and [`vv-visualize`](../vv-visualize) owns the operator-facing
surfaces — **vv-learn** owns the autonomous, contract-first
*improvement* loop that runs *over* recorded substrate state and
proposes changes back through the same TURN rules a human curator
follows.

> **Status: pre-v0.1.0 — placeholder.** This directory is reserved
> under the MagenticMarket monorepo; the gem has no source yet.
> The UX reference is [`../../docs/research/Press.md`](../../docs/research/Press.md)
> — the openprose/press "model is the CPU" pattern, adapted to a
> substrate whose write path is gated by TURNs, not by an LLM
> sandbox. Everything below describes the intended shape, not
> shipped code.

## The premise

The substrate **otherwise runs deterministically.** That is the
load-bearing word.

| Surface | Mode | Who drives |
|---|---|---|
| Read — users asking questions of the substrate | Deterministic | The substrate. SPARQL, OWL 2 RL, SHACL, recall traversals. No LLM in the answer path. |
| Write — authorized users initiating change | TURN-governed | A human, working through TURN rules: unambiguous descriptions, reconciled SME perspectives, staged diffs, SHACL pre-validation, published commits. |
| Improvement — closing the loop over recorded runs | TURN-governed, autonomously authored | **vv-learn.** Same TURN rules. The LLM is the author of the proposal, not a privileged actor. |

Users bring their own LLMs. The substrate does not call out to a
model in its hot path; it answers the user's questions from the
graph. When a user *wants change*, they open a TURN — and the TURN
is what reconciles SMEs, sharpens ambiguous language, stages diffs
through `vv-memory` Bronze, validates through SHACL, and publishes
through a `vv-process` definition.

**vv-learn earns no privileges the human doesn't have.** It runs
autonomously, but everything it proposes lands as a TURN that the
same rules apply to.

## What vv-learn does

1. **Reads recorded substrate state.** `Vv::Process::Run`
   timelines, `Vv::Decision::Decision` aggregates, Bronze episode
   logs, Silver triples with `vvmem:` provenance, Gold curated
   commitments, SHACL conformance scores, the Health Dashboard's
   5-dimension export from [`vv-visualize`](../vv-visualize).
2. **Writes contract-shaped programs.** Each improvement effort
   is a Press-style program: `requires:` / `ensures:` / `strategies:`
   / `shape.prohibited:`. The contracts are the durable artifact;
   the model is the CPU that satisfies them.
3. **Reconciles SME perspectives.** When two services or two
   recorded decisions disagree, vv-learn opens a reconciliation
   TURN — not a unilateral patch. The contract `requires` the
   ambiguity be named; the strategy is to surface it to operators
   through [`vv-visualize`](../vv-visualize)'s ontology hub.
4. **Authors unambiguous descriptions.** Every proposal vv-learn
   files names its evidence slice (which Silver triples, which
   Decision aggregates, which Run timelines), the contract it is
   satisfying, and the back-link to the originating episodes.
   Ambiguous proposals fail their own `ensures:` clause.
5. **Submits change through TURN, not behind it.** Ontology
   diffs stage as Bronze episodes; SHACL pre-validation runs
   before publish; the publish step is a `vv-process` definition
   that records the decision in `vv-decision`. vv-learn is the
   *author* of the TURN; an authorized human is the *committer*.
6. **Improves as models improve.** The contracts don't change;
   a smarter model satisfies the same contracts more efficiently.
   Per Press: *your programs are assets that appreciate with
   model capability.*

## Where it sits in the substrate

```
   ┌──────────────────────────────────────────────────────────┐
   │ vv-learn (this gem)                                      │
   │   contract-first improvement loop; LLM overseer;         │
   │   authors TURNs against recorded substrate state         │
   └──────────────────────────▲───────────────────────────────┘
                              │ stages ontology / shape /
                              │ extractor / process-def
                              │ proposals through TURN
   ┌──────────────────────────┴───────────────────────────────┐
   │ vv-visualize                                             │
   │   operator surfaces; reviews + publishes vv-learn TURNs  │
   └──────────────────────────▲───────────────────────────────┘
                              │
   ┌──────────────────────────┴───────────────────────────────┐
   │ vv-process                                               │
   │   deterministic process runtime; drives medallion jobs   │
   └──────────────────────────▲───────────────────────────────┘
                              │
   ┌──────────────────────────┴───────────────────────────────┐
   │ vv-decision                                              │
   │   the agent's reasoning loop — Decision aggregate root   │
   └──────────────────────────▲───────────────────────────────┘
                              │
   ┌──────────────────────────┴───────────────────────────────┐
   │ vv-memory                                                │
   │   Bronze (Episode) → Silver (Conformer) → Gold (Curator) │
   └──────────────────────────▲───────────────────────────────┘
                              │
   ┌──────────────────────────┴───────────────────────────────┐
   │ vv-graph + sqlite-sparql                                 │
   │   triples + reasoning + validation                       │
   └──────────────────────────────────────────────────────────┘
```

| Layer | Concern | Stays-in-its-lane test |
|---|---|---|
| **Learn** — `vv-learn` *(this gem)* | Contract-first improvement loop over recorded substrate state. Authors TURNs; never commits one. Brings its own model (per the bring-your-own-LLM rule). | Knows nothing about *triple storage* or *process scheduling*. Reads every layer below; writes only through the TURN entry points those layers already expose. |
| **Visualize** — [`vv-visualize`](../vv-visualize) | Operator-facing surfaces; the TURN review surface. | Renders; does not author. |
| **Process** — [`vv-process`](../vv-process) | Deterministic step machinery; replay. | Pinned wiring. vv-learn does not bypass it. |
| **Decision** — [`vv-decision`](../vv-decision) | The agent's reasoning loop. | One decision at a time. |
| **Memory** — [`vv-memory`](../vv-memory) | Medallion lifecycle storage. | Backward-looking. |
| **Graph** — [`vv-graph`](../vv-graph) | Triples, SPARQL, OWL 2 RL, SHACL Core/Rules, Scope. | Knows nothing about LLMs. |

Dependencies flow strictly down. **vv-learn is the only layer that
runs autonomously over a model**, and even it does so under TURN
rules — same as a human curator.

## The Press UX, adapted

vv-learn borrows openprose/press's posture from
[`../../docs/research/Press.md`](../../docs/research/Press.md):

| Press primitive | vv-learn equivalent |
|---|---|
| `requires:` / `ensures:` on a service | `requires:` / `ensures:` on an improvement program — the durable contract the proposal is judged against. |
| `shape.prohibited:` | TURN rules made machine-readable: *never bypass SHACL pre-validation, never publish without an authorized committer, never widen Gold without Curator evidence.* Hard refusals, not heuristics. |
| `strategies:` | Adaptation guidance — *when many low-confidence Silver triples, prefer raising a reconciliation TURN over a publish TURN.* |
| `press()` recursion | Sub-programs that fan out across recorded runs (one per `Vv::Process::Run`, fan-in to a synthesizer). |
| Filesystem-mediated worker communication | TURN-mediated. Workers communicate through Bronze episodes + staged Silver proposals — the substrate's filesystem. |
| Model-as-CPU | Same. The substrate is the JVM; TURN is the bytecode contract; the operator's model is the CPU. |

The departure from Press is the **commit gate.** Press programs
terminate when their exit contract is satisfied. vv-learn programs
terminate when their TURN is *filed* — publishing is a separate,
human-authorized step that runs through `vv-process` and records
through `vv-decision`. The LLM never holds the commit privilege.

## Sketch of the surface (not a contract)

```ruby
# An improvement program: contract-first, model-driven.
class Vv::Learn::OntologyTighteningProgram < Vv::Learn::Program
  requires :scope                    # the workspace / session to improve
  requires :evidence_window, default: 30.days
  ensures  :turn_filed               # exit contract: a TURN exists for review
  ensures  :no_unilateral_publish    # hard invariant per shape.prohibited

  strategies do
    on(:many_low_confidence_silver) { prefer :reconciliation_turn }
    on(:shacl_violations_rising)    { prefer :shape_tightening_turn }
  end

  shape do
    prohibited :bypass_shacl_pre_validation
    prohibited :publish_without_committer
    prohibited :widen_gold_without_curator_evidence
  end
end

# Running it. The model is "yours" — bring-your-own-LLM.
run = Vv::Learn.run!(
  Vv::Learn::OntologyTighteningProgram,
  scope: workspace,
  model: ctx.sample,                 # the substrate's LLM dispatcher
)

run.contracts_satisfied?             # => true | false
run.turns_filed                      # => [Vv::Visualize::Ontology::Proposal, ...]
run.evidence_slice                   # => the Silver triples + Decisions consulted
run.reasoning_trace                  # => recorded through vv-decision
run.replay!                          # contracts are stable; replay re-derives the turns
```

```ruby
# A reconciliation TURN — vv-learn's response to disagreeing SME perspectives.
Vv::Learn::Reconciliation.open(
  scope: workspace,
  perspectives: [
    { actor: :extractor_v3, predicate: "mm:status", object: '"open"',     confidence: 0.82 },
    { actor: :extractor_v4, predicate: "mm:status", object: '"reopened"', confidence: 0.78 },
  ],
  describe_unambiguously: <<~PROSE,
    Two extractor revisions disagree about order 42's status across the
    same Bronze episode (id: 17,432). Both pass SHACL. v3 maps the
    payload's "state":"open" literal; v4 reads the trailing
    "history[-1]":"reopened" element. The disagreement is a vocabulary
    gap, not a data conflict.
  PROSE
  proposed_resolution: :widen_ontology_with_skos_alt_label,
)
# => stages a Bronze episode; opens a TURN in vv-visualize's ontology hub
```

## Surface & boundaries

The gem owns:

- **`Vv::Learn::Program`** — the contract-first DSL: `requires:`,
  `ensures:`, `strategies:`, `shape.prohibited:`. The Press-shaped
  durable artifact.
- **`Vv::Learn::Run`** — the aggregate root for one improvement
  pass: evidence slice, reasoning trace, filed TURNs, contract
  outcomes. Records through `vv-decision`; persists through
  `vv-memory`.
- **`Vv::Learn::Reconciliation`** — the SME-reconciliation TURN
  authoring surface. Forces unambiguous-description discipline at
  the type level.
- **The model dispatcher** — a thin wrapper over `ctx.sample`
  honouring bring-your-own-LLM. No bundled model; no credentials
  in the substrate.
- **The hard refusals** — `shape.prohibited:` clauses enforced as
  pre-flight checks, not guidance. vv-learn cannot file a TURN
  that bypasses SHACL pre-validation; the program errors before
  the model is even asked.

The gem deliberately does **not** own:

- **Triple storage.** Stays in [`vv-graph`](../vv-graph).
- **The medallion.** Staged proposals ARE Bronze episodes;
  [`vv-memory`](../vv-memory) owns them.
- **Scheduling and replay.** Improvement programs *can* be driven
  by a [`vv-process`](../vv-process) definition for cadence; the
  step machinery stays there.
- **The reasoning aggregate.** Every model call vv-learn makes
  goes through [`vv-decision`](../vv-decision); the *why* lives on
  the `Decision` aggregate root, not in vv-learn's internals.
- **Operator review.** TURNs are reviewed and published through
  [`vv-visualize`](../vv-visualize)'s ontology hub + run timeline.
  vv-learn files; the operator commits.
- **Holding the commit privilege.** Authorized users initiate
  change. vv-learn is not an authorized user; it is an authorized
  *author of proposals*.

## Why this is a separate gem (vs. an MCB action)

1. **Different invariant.** MCB actions are deterministic,
   read-only or single-effect, gated on `input_schema` +
   `annotate(read_only:, destructive:, requires_confirmation:)`.
   vv-learn programs are *autonomous, model-driven, multi-step*
   and need their own contract grammar.
2. **Bring-your-own-LLM lives here.** The substrate's no-LLM-
   credentials principle is intact below this layer; vv-learn is
   the one place a model dispatcher is legitimate. Putting it on
   MCB would widen MCB's responsibility past "intent surface."
3. **TURN-authoring is its own concern.** Unambiguous-description
   discipline + SME reconciliation need a typed surface
   (`Vv::Learn::Reconciliation`) — they are not generic enough
   to belong on a generic action runner.
4. **Press-shape vs. MCB-shape.** Press's `requires:` /
   `ensures:` / `strategies:` / `shape.prohibited:` is structurally
   close to MCB's contract shape but not identical, and the
   substrate has named both ([`../../docs/research/Press.md`](../../docs/research/Press.md))
   as worth running side-by-side rather than collapsing.

## Dependencies

- **[`vv-visualize`](../vv-visualize)** — the TURN review surface;
  vv-learn files proposals that land in its ontology hub + run
  timeline.
- **[`vv-process`](../vv-process)** — cadence + replay for
  recurring improvement programs.
- **[`vv-decision`](../vv-decision)** — every model call records
  through it; the reasoning trace is a `Decision` aggregate.
- **[`vv-memory`](../vv-memory)** — Bronze episode emission for
  staged proposals; Silver triples for evidence slices; Gold
  commitments for context.
- **[`vv-graph`](../vv-graph)** — transitive, via `vv-memory`. No
  direct dependency.

`vv-learn` does **not** depend on `sqlite-sparql` directly. The
layering rule pinned in
[`../vv-graph/CONSUMER_REQUIREMENT_VV.md`](../vv-graph/CONSUMER_REQUIREMENT_VV.md)
extends one tier further up: a learning gem consumes the four
gems above it, not the storage engine.

## What this gem is NOT

- **Not an autonomous committer.** vv-learn never closes a TURN.
  It files; an authorized human commits.
- **Not a privileged actor.** Same TURN rules as a human curator:
  unambiguous descriptions, SHACL pre-validation, reconciled SME
  perspectives, staged diffs.
- **Not a model host.** Bring-your-own-LLM; the substrate
  dispatches through `ctx.sample`. No bundled credentials.
- **Not the substrate's hot path.** The deterministic stack runs
  fine without vv-learn. This gem is *additive* — improvement
  cadence, not request handling.
- **Not a tool-calling framework.** Per the Press model: contract-
  first, model-as-CPU, no function-schema sprawl. The model reads
  contracts and writes proposals; the substrate validates and
  files them.

## Cross-references

- [`../../docs/research/Press.md`](../../docs/research/Press.md) —
  the openprose/press contract-first, model-as-CPU pattern this
  gem's UX is modelled on; the departures (commit gate, TURN
  authoring, hard-refusal shapes) are spelled out above.
- [`../../docs/architecture/principles/journeys-and-flows-drive-development.md`](../../docs/architecture/principles/journeys-and-flows-drive-development.md)
  — the journey/flow discipline vv-learn programs are expected
  to honour when filing TURNs.
- [`../../docs/architecture/principles/grammar-and-llm-boundary.md`](../../docs/architecture/principles/grammar-and-llm-boundary.md)
  — the layer-4 "LLM residual" stance: vv-learn is exactly where
  the substrate spends model tokens, run on cadence rather than
  in the hot path.
- [`../../docs/architecture/principles/model-context-injection.md`](../../docs/architecture/principles/model-context-injection.md)
  — the MCB intent-layer doctrine. vv-learn complements MCB by
  occupying the autonomous-improvement role MCB deliberately
  refuses.

## License

MIT. Same as the rest of the MagenticMarket substrate.
