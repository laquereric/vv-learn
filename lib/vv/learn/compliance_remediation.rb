# frozen_string_literal: true

module Vv
  module Learn
    # Compliance remediation as a first-class vv-learn improvement loop —
    # the generalization of `CrReconciliation` from CR-doc reconciliation
    # to **any deterministic gate**.
    #
    # **Why this lives here.** A compliance gate (the CR audit, the S5
    # token-lint, the S6 host-chrome consume-don't-fork audit, …) is a
    # deterministic check: it produces a green/red verdict with no model
    # in the path. When a gate goes red, *authoring* the minimal fix is
    # non-deterministic, LLM-authored work: an agent reads the gate's
    # failure detail and *proposes* the edits that make it green again.
    # That is exactly vv-learn's charter. The LLM is the *author*; the
    # gate re-run (deterministic) is the *judge*; vv-learn earns no
    # privilege the human curator doesn't have.
    #
    # **The frozen rule (PLAN_0_93_4).** The model is NEVER in the
    # detection path. Detection stays deterministic elsewhere — this
    # module only authors remediation when a gate is *already* red, and
    # the runtime re-runs the SAME deterministic gate to satisfy
    # `:gate_green`. The LLM never decides compliance, only authors the
    # fix.
    #
    # **Why dispatch goes through vv-agent.** vv-learn never imports an
    # LLM SDK. Each per-violation remediation is dispatched through
    # `Vv::Agent` — the BYO-provider façade — so the loop is not
    # hardwired to any single model/runner.
    #
    # **Surfaces.** The contract (`ComplianceProgram`), the typed
    # `Violation`, input validation, and the instruction builder are
    # pure-Ruby and work standalone. `.open(...)` dispatches through
    # `Vv::Agent::Task.run!`. That entry **requires** `scope:` (the
    # `Vv::Memory::Scoped` that records the `agent_task` /
    # `agent_task_completed` Bronze pair) and `provider:` (a
    # `Vv::Agent::Provider::*` class). Per the BYO doctrine, `.open`
    # resolves the provider via `Vv::Agent.select` unless the caller
    # passes one — LN never names a concrete model. If the vv-agent
    # runtime is absent (older bundle), `.open` raises `RuntimeNotReady`
    # with a verbatim hint.
    module ComplianceRemediation
      # One red gate to remediate. `gate` is the gate name; `member` is
      # the repo/path the gate failed on; `detail` is the gate's failure
      # summary; `surface` is the glob the agent may edit — the
      # prohibition `:edit_outside_violating_surface` is enforced against
      # it.
      Violation = Data.define(:gate, :member, :detail, :surface) do
        def initialize(gate:, member:, detail:, surface:)
          unless gate.is_a?(String) && !gate.empty?
            raise ArgumentError, "Violation#gate must be a non-empty String"
          end
          unless member.is_a?(String) && !member.empty?
            raise ArgumentError, "Violation#member must be a non-empty String"
          end
          unless detail.is_a?(String) && !detail.empty?
            raise ArgumentError, "Violation#detail must be a non-empty String"
          end
          unless surface.is_a?(String) && !surface.empty?
            raise ArgumentError, "Violation#surface must be a non-empty String"
          end
          super
        end
      end

      # The provenance prefix. Each dispatched task is keyed
      # `compliance-fix:<gate>:<member>` so a re-run is resume-safe
      # (mirrors the `vv-process` `run_id:step` convention vv-agent
      # documents).
      PROVENANCE_PREFIX = "compliance-fix"

      module_function

      # Validate the input shape without dispatching. Returns `:ok`;
      # raises `ArgumentError` naming the offending constraint. Testable
      # in isolation — the rest of `.open` depends on the not-yet-landed
      # vv-agent runtime, but this discipline does not.
      def validate_inputs!(violations:)
        unless violations.is_a?(Array) && !violations.empty?
          raise ArgumentError,
                "ComplianceRemediation requires at least 1 violation, got " \
                "#{violations.is_a?(Array) ? violations.length : violations.class}."
        end

        unless violations.all? { |v| v.is_a?(Violation) }
          bad = violations.reject { |v| v.is_a?(Violation) }.first
          raise ArgumentError,
                "ComplianceRemediation violations must all be " \
                "Vv::Learn::ComplianceRemediation::Violation; got #{bad.class}. " \
                "Construct each with .new(gate:, member:, detail:, surface:)."
        end

        keys = violations.map { |v| "#{v.gate}+#{v.member}" }
        if keys.uniq.length != keys.length
          raise ArgumentError,
                "ComplianceRemediation violations must have distinct " \
                "gate+member keys; got duplicates: " \
                "#{keys.tally.select { |_, n| n > 1 }.keys.inspect}."
        end

        :ok
      end

      # Build the agent instructions for one violation. This is the
      # contract-first prompt: author the MINIMAL fix that makes THIS
      # gate green, editing only within the violating surface, doc/config
      # over code, committing in the correct repo boundary. Pure string
      # construction — no dispatch.
      def instructions_for(violation:)
        <<~PROMPT.strip
          Gate '#{violation.gate}' is RED on #{violation.member}:
          #{violation.detail}

          Author the MINIMAL fix that makes that gate green again. Edit
          ONLY within #{violation.surface}. Do not make unnecessary code
          changes when a doc/config fix suffices.

          Commit in the correct repo boundary (#{violation.member}); never
          force-push.
        PROMPT
      end

      # The entry point. Validates inputs, then dispatches one agent task
      # per violation **through vv-agent** (never a hardwired model).
      # Non-halting: a failing violation is collected, not fatal; returns
      # a results array `[{ gate:, member:, ok:, detail: }]`.
      #
      # `scope:` is required — it is the `Vv::Memory::Scoped` that
      # `Vv::Agent::Task.run!` records the Bronze episode pair against.
      # `provider:` may be passed explicitly; otherwise it is resolved
      # BYO via `Vv::Agent.select(required:, prefer:)` so LN stays
      # model-agnostic. If the vv-agent runtime is absent, raises
      # `RuntimeNotReady`.
      def open(violations:, scope:, provider: nil,
               required: {}, prefer: {}, agent: nil, mcp_servers: [], timeout: 600)
        validate_inputs!(violations: violations)

        unless defined?(::Vv::Agent::Task) && ::Vv::Agent::Task.respond_to?(:run!)
          raise ::Vv::Learn::Errors::RuntimeNotReady,
                "Vv::Learn::ComplianceRemediation.open dispatches through " \
                "Vv::Agent::Task.run!, which is not available in the " \
                "bundled vv-agent. Bundle a vv-agent with the Task " \
                "runtime (the gate-remediation runtime), or run the " \
                "deterministic gates directly until it lands."
        end

        # BYO-provider: resolve through the registry unless the caller
        # supplied a concrete provider class.
        provider ||= ::Vv::Agent.select(required: required, prefer: prefer)

        violations.map do |violation|
          begin
            result = ::Vv::Agent::Task.run!(
              scope:         scope,
              provider:      provider,
              instructions:  instructions_for(violation: violation),
              agent:         agent,
              mcp_servers:   mcp_servers,
              timeout:       timeout,
              provenance_id: "#{PROVENANCE_PREFIX}:#{violation.gate}:#{violation.member}",
            )
            { gate: violation.gate, member: violation.member, ok: true, detail: result }
          rescue => e
            # Non-halting: record and continue to the next violation.
            { gate: violation.gate, member: violation.member, ok: false,
              detail: "#{e.class}: #{e.message}" }
          end
        end
      end
    end

    # The contract for a compliance-remediation improvement loop — the
    # plan's `ComplianceProgram < Vv::Learn::Program`. Same Press grammar
    # as the other Programs; compiles + freezes today even though the
    # dispatch runtime is pending.
    #
    # The runtime re-runs the SAME deterministic gate to satisfy
    # `:gate_green`; the LLM never decides compliance, it only authors
    # the fix. Phase E wires the sweep to call this when triage decides
    # `:auto_fix`.
    #
    # The `prohibited:` clauses encode the hard safety limits the CR
    # bootstrap learned the expensive way, generalized to any gate: the
    # agent edits only within the violating surface, never makes
    # unnecessary code changes when a doc/config fix suffices, commits
    # inside the violating member's own boundary (never staging the MM
    # superproject), and never force-pushes over a remote ahead of the
    # local snapshot.
    class ComplianceRemediation::ComplianceProgram < Program
      requires :gate
      requires :member

      ensures :gate_green

      shape do
        prohibited :edit_outside_violating_surface
        prohibited :unnecessary_code_changes
        prohibited :commit_in_mm_boundary
        prohibited :force_push_over_newer_remote
      end
    end
  end
end
