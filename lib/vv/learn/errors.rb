# frozen_string_literal: true

module Vv
  module Learn
    module Errors
      # Loading-time guard fired when the host bundle doesn't include
      # the prerequisite vv-memory facades (PREREQ-A
      # `Vv::Memory::Scoped#shacl_validate` + PREREQ-B
      # `Vv::Memory::TurnEpisode`) or the prerequisite vv-decision
      # nested-consider loop (PREREQ-C, vv-decision >= 0.2.0).
      # Raised by the Engine's `after_initialize` block.
      class MissingDependency < StandardError; end

      # Raised by `Vv::Learn.run!` when an input fails the program's
      # `requires:` clause, or when a post-block `ensures:` symbol
      # evaluates to false. Carries `phase:` (`:inputs` / `:exit`)
      # and the failed clause symbol.
      class ContractFailed < StandardError
        attr_reader :phase, :clause

        def initialize(message, phase:, clause:)
          super(message)
          @phase  = phase
          @clause = clause
        end
      end

      # Raised by the hard-refusal pre-flight when a `shape.prohibited:`
      # invariant would be violated. Carries the refusal symbol that
      # tripped. **Raised before any model call** — operators
      # dashboarding refusals get the symbol; operators debugging a
      # specific refusal walk the `cause:` chain for the underlying
      # SHACL / committer / curator failure detail.
      class ProhibitedAction < StandardError
        attr_reader :refusal

        def initialize(message, refusal:)
          super(message)
          @refusal = refusal
        end
      end

      # Raised when a `Vv::Learn::Program` subclass mutates its
      # contract (`requires` / `ensures` / `prohibited`) after
      # `.compile` has frozen it. The no-backwards-compat invariant:
      # contracts don't shift mid-run.
      class ContractFrozen < StandardError; end

      # Raised by `Vv::Learn::Run#replay!`. v0.1.0 records the
      # `started_at_token` column to enable the additive landing in
      # 0.2.0, but the implementation itself is deferred. Refusal
      # symbol pinned.
      class ReplayNotYetSupported < StandardError; end

      # Defined but not raised by v0.1.0's `run!`. Operators may use
      # it themselves when their program is expected to file a TURN
      # but didn't (the abandoned-improvement case where the
      # deliberate block exited without appending any TurnEpisode).
      class NoTurnFiled < StandardError; end

      # Raised when a v0.2.0 surface (`Vv::Learn::Reconciliation.open`)
      # is invoked before its v0.1.0 Phase C runtime dependency
      # (`Vv::Learn.run!`) has landed. The partial-landing escape
      # hatch — input-validation surfaces work today, runtime
      # dispatch surfaces wait on sibling-gem prerequisites.
      class RuntimeNotReady < StandardError; end
    end
  end
end
