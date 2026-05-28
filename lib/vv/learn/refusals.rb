# frozen_string_literal: true

module Vv
  module Learn
    # The hard-refusal pre-flight registry (PLAN_0_1_0 Phase B′). The
    # load-bearing invariant of the gem: `shape.prohibited:` clauses
    # are **not guidance** — they are pre-flight checks that fail the
    # program **before any token is spent**.
    #
    # Each entry in `REGISTRY` maps a pinned refusal symbol to a
    # lambda. The runtime (`Vv::Learn.run!`, Phase C) calls
    # `Vv::Learn::Refusals.check!(contract, **inputs)` after compiling
    # the Program and validating inputs, but **before** opening the
    # `Vv::Decision.deliberate` block and constructing the
    # `ModelDispatcher`. If any check returns false, `ProhibitedAction`
    # is raised; the model is never asked.
    #
    # The three v0.1.0 symbols are pinned for the v0.x.x line.
    # Additive symbols are allowed in 0.1.x; subtractive changes
    # require a new PLAN.
    module Refusals
      # The registry. Frozen at load time. Each lambda receives the
      # keyword arguments the runtime passes to `check!`; the lambda
      # extracts what it needs.
      #
      # **Contract:** the lambda returns truthy when the refusal is
      # NOT tripped (i.e., the action is allowed). It returns falsey
      # when the refusal IS tripped (the action would violate the
      # `shape.prohibited:` invariant) — `check!` then raises
      # `ProhibitedAction` naming the failed symbol.
      #
      # The lambda may also raise its own exception (e.g., when the
      # underlying SHACL facade itself errors); that exception
      # propagates as the `cause:` of `ProhibitedAction`.
      REGISTRY = {
        # PREREQ-A — `Vv::Memory::Scoped#shacl_validate` returns a
        # Result monad. Success means the diff conforms to the
        # scope's SHACL shapes; failure means it would not. We
        # **refuse to spend tokens** on a program whose target diff
        # would fail SHACL.
        bypass_shacl_pre_validation: ->(scope:, diff:, **) {
          scope.shacl_validate(diff).success?
        },

        # vv-learn never holds the committer privilege. A staged
        # TurnEpisode emitted under vv-learn's authorship must leave
        # `committer_ref` nil — an authorized human commits it later
        # through the operator surfaces.
        publish_without_committer: ->(turn:, **) {
          turn.committer_ref.nil?
        },

        # Gold-tier widenings require Curator evidence. If the diff
        # doesn't touch Gold, the check passes vacuously. If it
        # does, the diff must carry Curator-evidence provenance.
        widen_gold_without_curator_evidence: ->(diff:, **) {
          if diff.respond_to?(:touches_gold?) && diff.touches_gold?
            diff.has_curator_evidence?
          else
            true
          end
        },
      }.freeze

      module_function

      # Run pre-flight for every symbol in `contract.prohibited`.
      # Raises `ProhibitedAction` naming the failed symbol on the
      # first refusal that trips. Returns `:ok` on success.
      #
      # The runtime is expected to pass enough keyword arguments to
      # satisfy whichever lambdas the contract names — typically
      # `scope:`, `diff:`, and `turn:`. Lambdas use Ruby's
      # keyword-rest (`**`) so they ignore kwargs they don't need.
      def check!(contract, **context)
        contract.prohibited.each do |symbol|
          checker = REGISTRY.fetch(symbol) do
            raise ::Vv::Learn::Errors::ProhibitedAction.new(
              "Unknown refusal symbol :#{symbol} declared in " \
              "#{contract.program_class.name || '(anonymous Program)'}'s " \
              "shape.prohibited:. v0.1.0 registry keys: " \
              "#{REGISTRY.keys.inspect}.",
              refusal: symbol,
            )
          end

          allowed =
            begin
              checker.call(**context)
            rescue ArgumentError => e
              raise ::Vv::Learn::Errors::ProhibitedAction.new(
                "Refusal :#{symbol} could not be evaluated — its " \
                "checker requires keyword arguments not supplied " \
                "by the runtime (#{e.message}). The runtime " \
                "passed: #{context.keys.inspect}.",
                refusal: symbol,
              )
            end

          unless allowed
            raise ::Vv::Learn::Errors::ProhibitedAction.new(
              "Refusal :#{symbol} tripped — " \
              "#{contract.program_class.name || '(anonymous Program)'} " \
              "would violate its shape.prohibited: invariant. " \
              "No model tokens were spent.",
              refusal: symbol,
            )
          end
        end

        :ok
      end
    end
  end
end
