# frozen_string_literal: true

module Vv
  module Learn
    # The SME-reconciliation TURN authoring surface (PLAN_0_2_0
    # Phase A). Reconciliation is a specialization of the generic
    # Program round-trip — same hard-refusal pre-flight, same
    # TurnEpisode emission, same contract evaluation — with two
    # typing constraints that the generic Program doesn't enforce:
    #
    # 1. Two or more `Perspective` value objects (typed actor +
    #    predicate + object + confidence), passed in `perspectives:`.
    # 2. An `describe_unambiguously:` prose string that satisfies
    #    a minimum-length and minimum-discrimination check.
    #
    # The README sketches the surface; this module makes the
    # discipline machine-enforceable.
    #
    # **v0.2.0 partial landing.** The `Perspective` Data class +
    # `RESOLUTIONS` enum + input validation ship as pure-Ruby surfaces
    # now. The `.open(...)` runtime delegation through
    # `Vv::Learn.run!` requires v0.1.0 Phase C (the runtime body) to
    # have landed, which depends on PREREQ-A/B/C in sibling gems.
    # Calling `.open` before that lands raises `RuntimeNotReady`
    # with a verbatim hint.
    module Reconciliation
      # Typed perspective. Each perspective names an actor
      # (extractor revision, agent, curator) whose claim about a
      # predicate-object pair is what disagrees with another
      # actor's claim about the same predicate. The confidence is
      # the actor's self-reported certainty in `[0.0, 1.0]`.
      Perspective = Data.define(:actor, :predicate, :object, :confidence) do
        def initialize(actor:, predicate:, object:, confidence:)
          unless actor.is_a?(Symbol)
            raise ArgumentError, "Perspective#actor must be a Symbol, got #{actor.class}"
          end
          unless predicate.is_a?(String) && !predicate.empty?
            raise ArgumentError, "Perspective#predicate must be a non-empty String"
          end
          unless object.is_a?(String) && !object.empty?
            raise ArgumentError, "Perspective#object must be a non-empty String"
          end
          unless confidence.is_a?(Numeric) && (0.0..1.0).cover?(confidence)
            raise ArgumentError, "Perspective#confidence must be Numeric in [0.0, 1.0], got #{confidence.inspect}"
          end
          super
        end
      end

      # Pinned resolution-strategy enum (PLAN_0_2_0 contract
      # additions). Additive symbols allowed in 0.2.x; subtractive
      # changes require a new PLAN.
      RESOLUTIONS = %i[
        widen_ontology_with_skos_alt_label
        prefer_higher_confidence
        defer_to_curator
        request_extractor_revision
      ].freeze

      # Minimum prose length for an unambiguous description.
      # Coarse — the real discrimination check is
      # `description_discriminates?` below, which is stricter.
      MIN_DESCRIPTION_LENGTH = 80

      module_function

      # Validates the input shape without dispatching. Returns
      # `:ok` on success; raises `ArgumentError` with the offending
      # constraint on failure.
      #
      # This is the surface the runtime calls *before* opening the
      # `Vv::Decision.deliberate` block in v0.2.0's Phase A
      # runtime body. Splitting it out as a module method makes
      # the input-validation discipline testable in isolation —
      # crucial because the rest of the runtime depends on v0.1.0
      # Phase C, which is blocked on sibling-gem prerequisites.
      def validate_inputs!(perspectives:, describe_unambiguously:, proposed_resolution:)
        unless perspectives.is_a?(Array) && perspectives.length >= 2
          raise ArgumentError,
                "Reconciliation requires at least 2 perspectives, got " \
                "#{perspectives.is_a?(Array) ? perspectives.length : perspectives.class}."
        end

        unless perspectives.all? { |p| p.is_a?(Perspective) }
          bad = perspectives.reject { |p| p.is_a?(Perspective) }.first
          raise ArgumentError,
                "Reconciliation perspectives must all be " \
                "Vv::Learn::Reconciliation::Perspective; got " \
                "#{bad.class}. Construct each with .new(actor:, " \
                "predicate:, object:, confidence:)."
        end

        actors = perspectives.map(&:actor)
        if actors.uniq.length != actors.length
          raise ArgumentError,
                "Reconciliation perspectives must have distinct " \
                "actors; got duplicates: " \
                "#{actors.tally.select { |_, n| n > 1 }.keys.inspect}."
        end

        unless describe_unambiguously.is_a?(String) &&
               describe_unambiguously.length >= MIN_DESCRIPTION_LENGTH
          raise ArgumentError,
                "Reconciliation describe_unambiguously must be a " \
                "String of at least #{MIN_DESCRIPTION_LENGTH} characters; " \
                "got #{describe_unambiguously.is_a?(String) ? "#{describe_unambiguously.length} chars" : describe_unambiguously.class}."
        end

        unless RESOLUTIONS.include?(proposed_resolution)
          raise ArgumentError,
                "Reconciliation proposed_resolution must be one of " \
                "#{RESOLUTIONS.inspect}; got #{proposed_resolution.inspect}."
        end

        :ok
      end

      # The `:description_discriminates` ensures-check (PLAN_0_2_0
      # Phase A contract additions). Coarse heuristic: every
      # actor symbol AND at least one object literal from each
      # perspective appears in the prose. The richer check is a
      # v0.3.0 design question.
      def description_discriminates?(perspectives:, describe_unambiguously:)
        prose = describe_unambiguously.to_s
        perspectives.all? do |p|
          prose.include?(p.actor.to_s) && prose.include?(p.object)
        end
      end

      # The `.open(...)` entry point. v0.2.0's full implementation
      # validates inputs, then calls `Vv::Learn.run!` with the
      # `ReconciliationProgram` contract. Until v0.1.0 Phase C
      # lands (PREREQ-A/B/C in sibling gems), this raises
      # `RuntimeNotReady` with a verbatim hint.
      def open(scope:, perspectives:, describe_unambiguously:,
               proposed_resolution:, model:)
        validate_inputs!(
          perspectives:           perspectives,
          describe_unambiguously: describe_unambiguously,
          proposed_resolution:    proposed_resolution,
        )

        unless ::Vv::Learn.respond_to?(:run!)
          raise ::Vv::Learn::Errors::RuntimeNotReady,
                "Vv::Learn::Reconciliation.open requires Vv::Learn.run! " \
                "(v0.1.0 Phase C). The runtime body depends on " \
                "PREREQ-A (Vv::Memory::Scoped#shacl_validate), " \
                "PREREQ-B (Vv::Memory::TurnEpisode), and PREREQ-C " \
                "(vv-decision >= 0.2.0 nested-consider loop). " \
                "Bundle the prerequisite versions to enable the " \
                "runtime."
        end

        ::Vv::Learn.run!(
          ReconciliationProgram,
          scope:                   scope,
          model:                   model,
          perspectives:            perspectives,
          unambiguous_description: describe_unambiguously,
          proposed_resolution:     proposed_resolution,
        )
      end
    end

    # The contract for a reconciliation TURN. Inherits the v0.1.0
    # contract grammar; declares the two new ensures symbols
    # (`:perspectives_named`, `:description_discriminates`) and
    # reuses the v0.1.0 refusal symbols.
    #
    # **Contract-only class in v0.2.0 partial landing.** Compiles
    # and freezes correctly; the runtime body that consumes it
    # waits on v0.1.0 Phase C.
    class Reconciliation::ReconciliationProgram < Program
      requires :perspectives
      requires :unambiguous_description
      requires :proposed_resolution

      ensures :turn_filed
      ensures :no_unilateral_publish
      ensures :perspectives_named
      ensures :description_discriminates

      shape do
        prohibited :bypass_shacl_pre_validation
        prohibited :publish_without_committer
      end
    end
  end
end
