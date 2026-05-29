# frozen_string_literal: true

require "vv/learn/version"
require "vv/learn/errors"

# The vv-memory dependency. We require it eagerly so the
# `MissingDependency` guard in `Engine` can speak to a definite
# state — present, or refused with a verbatim hint. Likewise
# vv-decision: every model call inside `run!` records through
# `Vv::Decision.deliberate`'s nested-consider loop.
begin
  require "vv/memory"
rescue LoadError
  # Surface the failure mode at boot, not at first call. The
  # Engine's `after_initialize` block performs the final check;
  # consumers running outside Rails get the same hint via the
  # constant-presence checks on `Vv::Memory::Scoped` +
  # `Vv::Memory::TurnEpisode`.
end

begin
  require "vv/decision"
rescue LoadError
  # See above. Engine's guard catches the PREREQ-C miss.
end

# Phase B — the contract DSL. Pure Ruby; no Rails dependency.
require "vv/learn/program"

# Phase B′ — the hard-refusal registry. Pure Ruby; the checkers
# are lambdas that the runtime invokes pre-flight.
require "vv/learn/refusals"

# PLAN_0_2_0 Phase A pure-Ruby — `Reconciliation::Perspective` Data
# class, `RESOLUTIONS` symbol enum, `validate_inputs!` discipline.
# The `.open(...)` runtime delegation requires v0.1.0 Phase C and
# raises `RuntimeNotReady` until it lands.
require "vv/learn/reconciliation"

# CR-reconciliation improvement loop — `CrReconciliation::Target`,
# `CrReconciliationProgram` contract, `validate_inputs!`, and the
# instruction builder are pure-Ruby surfaces now. `.open(...)`
# dispatches through `Vv::Agent` (BYO-provider façade) and raises
# `RuntimeNotReady` until vv-agent's Task runtime lands.
require "vv/learn/cr_reconciliation"

# Compliance-remediation improvement loop — the generalization of
# `CrReconciliation` from CR docs to ANY deterministic gate.
# `ComplianceRemediation::Violation`, `ComplianceProgram` contract,
# `validate_inputs!`, and the instruction builder are pure-Ruby
# surfaces now. `.open(...)` dispatches through `Vv::Agent` (BYO-provider
# façade) and raises `RuntimeNotReady` until vv-agent's Task runtime lands.
require "vv/learn/compliance_remediation"

# Rails-app context bootstraps the Engine + AR model. Phase C/D
# surfaces (Run, Runtime, ModelDispatcher) load through the Engine.
if defined?(::Rails::Engine)
  require "vv/learn/engine"
end
