# frozen_string_literal: true

module Vv
  module Learn
    # Consumer-Requirement reconciliation as a first-class vv-learn
    # improvement loop.
    #
    # **Why this lives here.** Reconciling each vendor submodule's
    # `CONSUMER_REQUIREMENT_*` files against the substrate's driving
    # plans is non-deterministic, LLM-authored work: an agent reads the
    # plans + the gem's current contract and *proposes* the doc edits.
    # That is exactly vv-learn's charter — "the autonomous,
    # contract-first improvement loop that runs over recorded substrate
    # state and proposes changes back through the same rules a human
    # curator follows." The LLM is the *author*; a human is the
    # *committer*; vv-learn earns no privilege the human doesn't have.
    #
    # **Why dispatch goes through vv-agent.** vv-learn never imports an
    # LLM SDK. Each per-submodule reconciliation is dispatched through
    # `Vv::Agent` — the BYO-provider façade — so the loop is not
    # hardwired to any single model/runner. (Historically this ran as
    # `scripts/cr-reconcile-sweep.rb` in the MM superproject, shelling
    # `claude -p` directly; that script is the pre-runtime bootstrap.
    # This module is the canonical home.)
    #
    # **Partial landing, mirroring `Vv::Learn::Reconciliation`.** The
    # contract (`CrReconciliationProgram`), the typed `Target`, input
    # validation, and the instruction builder are pure-Ruby surfaces
    # that work today. `.open(...)` dispatches through `Vv::Agent`, but
    # the live agent runtime (`Vv::Agent::Task.run!`, vv-agent Phase D)
    # is not yet implemented — so `.open` raises `RuntimeNotReady` with
    # a verbatim hint until the provider runtime lands. Same posture as
    # `Reconciliation.open` waiting on `Vv::Learn.run!`.
    module CrReconciliation
      # A submodule to reconcile. `cr_glob` scopes which files the
      # agent may touch — the prohibition `:edit_outside_cr_files` is
      # enforced against it.
      Target = Data.define(:name, :path, :cr_glob) do
        def initialize(name:, path:, cr_glob: "CONSUMER_REQUIREMENT_*.md")
          unless name.is_a?(String) && !name.empty?
            raise ArgumentError, "Target#name must be a non-empty String"
          end
          unless path.is_a?(String) && !path.empty?
            raise ArgumentError, "Target#path must be a non-empty String"
          end
          unless cr_glob.is_a?(String) && !cr_glob.empty?
            raise ArgumentError, "Target#cr_glob must be a non-empty String"
          end
          super
        end
      end

      # The default provenance prefix. Each dispatched task is keyed
      # `cr-reconcile:<sub>` so a re-run is resume-safe (mirrors the
      # `vv-process` `run_id:step` convention vv-agent documents).
      PROVENANCE_PREFIX = "cr-reconcile"

      module_function

      # Validate the input shape without dispatching. Returns `:ok`;
      # raises `ArgumentError` naming the offending constraint. Testable
      # in isolation — the rest of `.open` depends on the not-yet-landed
      # vv-agent runtime, but this discipline does not.
      def validate_inputs!(targets:, plans:)
        unless targets.is_a?(Array) && !targets.empty?
          raise ArgumentError,
                "CrReconciliation requires at least 1 target, got " \
                "#{targets.is_a?(Array) ? targets.length : targets.class}."
        end

        unless targets.all? { |t| t.is_a?(Target) }
          bad = targets.reject { |t| t.is_a?(Target) }.first
          raise ArgumentError,
                "CrReconciliation targets must all be " \
                "Vv::Learn::CrReconciliation::Target; got #{bad.class}. " \
                "Construct each with .new(name:, path:, cr_glob:)."
        end

        names = targets.map(&:name)
        if names.uniq.length != names.length
          raise ArgumentError,
                "CrReconciliation targets must have distinct names; got " \
                "duplicates: #{names.tally.select { |_, n| n > 1 }.keys.inspect}."
        end

        unless plans.is_a?(Array) && !plans.empty? && plans.all? { |p| p.is_a?(String) && !p.empty? }
          raise ArgumentError,
                "CrReconciliation requires a non-empty Array of plan " \
                "paths (Strings) to reconcile against; got #{plans.inspect}."
        end

        :ok
      end

      # Build the agent instructions for one submodule. This is the
      # contract-first prompt: reconcile THIS repo's CR files against
      # the named plans, edit + commit in-repo, contracts/docs only.
      # Pure string construction — no dispatch.
      def instructions_for(target:, plans:)
        <<~PROMPT.strip
          Reconcile this repository's #{target.cr_glob} files against the
          MagenticMarket substrate plans: #{plans.join(', ')}.

          Edit and commit in THIS repository (#{target.name}) only. Make
          contract/doc edits ONLY — change no code. Preserve every
          mandatory section the substrate CR audit requires, and for
          facet-split CRs keep the PINNED / SUBSTITUTABLE markers intact.

          When done, commit in-repo with a message referencing the
          reconciliation; do not touch files outside #{target.cr_glob}.
        PROMPT
      end

      # The entry point. Validates inputs, then dispatches one agent
      # task per target **through vv-agent** (never a hardwired model).
      # Non-halting: a failing target is collected, not fatal; returns
      # a results array `[{ target:, ok:, detail: }]`.
      #
      # Guarded exactly like `Reconciliation.open`: until vv-agent's
      # provider runtime (`Vv::Agent::Task.run!`, Phase D) lands, this
      # raises `RuntimeNotReady` with a verbatim hint. The MM-side
      # `scripts/cr-reconcile-sweep.rb` bootstrap covers the interim.
      def open(targets:, plans:, agent: nil, mcp_servers: [], timeout: 600)
        validate_inputs!(targets: targets, plans: plans)

        unless defined?(::Vv::Agent::Task) && ::Vv::Agent::Task.respond_to?(:run!)
          raise ::Vv::Learn::Errors::RuntimeNotReady,
                "Vv::Learn::CrReconciliation.open dispatches through " \
                "Vv::Agent::Task.run! (vv-agent Phase D), which has not " \
                "landed. Until it does, use the MM bootstrap driver " \
                "scripts/cr-reconcile-sweep.rb (shells the agent CLI " \
                "directly). Bundle a vv-agent with the Task runtime to " \
                "enable provider-dispatched reconciliation."
        end

        targets.map do |target|
          begin
            result = ::Vv::Agent::Task.run!(
              agent:         agent,
              instructions:  instructions_for(target: target, plans: plans),
              mcp_servers:   mcp_servers,
              timeout:       timeout,
              provenance_id: "#{PROVENANCE_PREFIX}:#{target.name}",
            )
            { target: target.name, ok: true, detail: result }
          rescue => e
            # Non-halting: record and continue to the next target.
            { target: target.name, ok: false, detail: "#{e.class}: #{e.message}" }
          end
        end
      end
    end

    # The contract for a CR-reconciliation improvement loop. Same Press
    # grammar as the other Programs; compiles + freezes today even
    # though the dispatch runtime is pending.
    #
    # The `prohibited:` clauses encode the hard safety limits the MM
    # bootstrap learned the expensive way: the agent edits only CR
    # files, never code; it commits inside the submodule's own boundary
    # (never staging the MM superproject); and it never force-pushes
    # over a remote that is ahead of the local snapshot.
    class CrReconciliation::CrReconciliationProgram < Program
      requires :targets
      requires :plans

      ensures :cr_reconciled
      ensures :committed_in_sub_boundary
      ensures :audit_green

      shape do
        prohibited :edit_outside_cr_files
        prohibited :code_changes
        prohibited :commit_in_mm_boundary
        prohibited :force_push_over_newer_remote
      end
    end
  end
end
