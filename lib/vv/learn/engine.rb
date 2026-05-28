# frozen_string_literal: true

require "rails/engine"

module Vv
  module Learn
    # The autonomous, contract-first improvement loop that runs over
    # recorded substrate state and proposes changes back through the
    # same TURN rules a human curator follows.
    #
    # v0.1.0 ships the minimum viable round-trip:
    # - `Vv::Learn::Program` DSL — `requires:` / `ensures:` /
    #   `shape.prohibited:` (Phase B).
    # - `Vv::Learn::Refusals` — hard-refusal pre-flight (Phase B′);
    #   raises `ProhibitedAction` **before any model call**.
    # - `Vv::Learn::Run` AR aggregate root (Phase C).
    # - `Vv::Learn::ModelDispatcher` — BYO-LLM wrapper (Phase D).
    #
    # The `Vv::Learn::Reconciliation` typed surface, `strategies`
    # adaptation DSL, sub-program recursion, `replay!`, the
    # `vv-visualize` review UI integration, and the `vv-process`
    # cadence binding land in 0.2.0+. See `docs/plans/PLAN_0_1_0.md`.
    class Engine < ::Rails::Engine
      isolate_namespace Vv::Learn

      config.eager_load_namespaces << Vv::Learn

      # PLAN_0_1_0 Phase A — refuse to boot if the prerequisite
      # surfaces are unavailable. Three checks:
      #
      # 1. `Vv::Memory::Scoped` — the polymorphic-scope concern that
      #    carries `record_episode` and (PREREQ-A) `shacl_validate`.
      # 2. `Vv::Memory::Scoped#shacl_validate` — PREREQ-A facade
      #    that delegates into vv-graph. Phase B′'s
      #    `:bypass_shacl_pre_validation` refusal calls it; without
      #    it, the hard-refusal pre-flight has no teeth.
      # 3. `Vv::Memory::TurnEpisode` — PREREQ-B typed subclass.
      #    `Vv::Learn::Run#turns_filed` returns this collection.
      #
      # The vv-decision presence is checked via the gem's VERSION
      # constant (>= 0.2.0 implies the nested-consider loop is
      # available). Constants alone don't tell us the loop semantics
      # are correct, so the gemspec also pins `vv-decision >= 0.1.0`
      # — that pin tightens to 0.2.0 once PREREQ-C ships.
      config.after_initialize do
        prereqs_ok =
          defined?(::Vv::Memory::Scoped) &&
          ::Vv::Memory::Scoped.instance_methods.include?(:shacl_validate) &&
          defined?(::Vv::Memory::TurnEpisode) &&
          defined?(::Vv::Decision) && ::Vv::Decision.respond_to?(:deliberate)

        unless prereqs_ok
          raise ::Vv::Learn::Errors::MissingDependency,
                "Vv::Learn depends on Vv::Memory::Scoped#shacl_validate " \
                "(PREREQ-A), Vv::Memory::TurnEpisode (PREREQ-B), and " \
                "Vv::Decision.deliberate with nested-consider semantics " \
                "(PREREQ-C, vv-decision >= 0.2.0). " \
                "bundle the prerequisite vv-memory and vv-decision " \
                "versions alongside vv-learn."
        end
      end
    end
  end
end
