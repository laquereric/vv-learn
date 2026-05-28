# frozen_string_literal: true

module Vv
  module Learn
    # The Press-shaped contract grammar. Subclass this, declare
    # `requires:` / `ensures:` / `shape { prohibited: }` /
    # `strategies do ... end` at class-definition time, then call
    # `.compile` to freeze the contract.
    #
    # **The compiled contract is the durable artifact**; the model is
    # the CPU that satisfies it. Per Press's posture: contracts don't
    # shift mid-run — the no-backwards-compat invariant is enforced
    # by `ContractFrozen`.
    #
    #   class OntologyTighteningProgram < Vv::Learn::Program
    #     requires :scope
    #     requires :evidence_window, default: 30 * 24 * 60 * 60   # 30 days
    #
    #     ensures :turn_filed
    #     ensures :no_unilateral_publish
    #
    #     strategies do
    #       on(:many_low_confidence_silver) { prefer :reconciliation_turn }
    #       on(:shacl_violations_rising)    { prefer :shape_tightening_turn }
    #     end
    #
    #     shape do
    #       prohibited :bypass_shacl_pre_validation
    #       prohibited :publish_without_committer
    #       prohibited :widen_gold_without_curator_evidence
    #     end
    #   end
    #
    # Strategies are **advisory** — they adjust which prompts the
    # ModelDispatcher constructs but do NOT participate in
    # `contracts_satisfied?` evaluation. The contract-bearing
    # clauses are `requires:`, `ensures:`, and `shape.prohibited:`.
    class Program
      # Sentinel marking a `requires :foo` declaration with no
      # default — distinguishes "required input" from
      # `requires :foo, default: nil` (optional, defaulting to nil).
      # The runtime compares against this constant when validating
      # inputs against the contract's requires list.
      REQUIRED = Object.new.tap do |obj|
        def obj.inspect; "Vv::Learn::Program::REQUIRED"; end
        def obj.to_s; "Vv::Learn::Program::REQUIRED"; end
      end.freeze

      # Frozen value object returned by `.compile`. Carries everything
      # the runtime needs to drive a Run — the inputs to validate,
      # the post-block ensures to evaluate, the pre-flight
      # prohibitions to refuse on, and the advisory strategies that
      # adjust prompt construction.
      Contract = Struct.new(
        :program_class,
        :requires,      # [{ name: Symbol, default: any }]
        :ensures,       # [Symbol]
        :prohibited,    # [Symbol]
        :strategies,    # { Symbol => Proc } — advisory, NOT contract-bearing
        keyword_init: true,
      ) do
        def freeze!
          requires.each(&:freeze)
          requires.freeze
          ensures.freeze
          prohibited.freeze
          strategies.freeze
          freeze
        end
      end

      class << self
        # Class-level DSL. Each call appends to a class-level array.
        # After `.compile` has memoized a frozen Contract, further
        # calls raise `ContractFrozen` — the no-backwards-compat
        # invariant.
        def requires(name, default: REQUIRED)
          guard_unfrozen!(:requires)
          _requires << { name: name, default: default }
        end

        def ensures(name)
          guard_unfrozen!(:ensures)
          _ensures << name
        end

        # `shape do ... prohibited :sym ... end` block. The block is
        # evaluated in the context of a small DSL helper so
        # `prohibited :sym` reads naturally; the actual storage is
        # the same `_prohibited` array.
        def shape(&block)
          guard_unfrozen!(:shape)
          raise ArgumentError, "shape requires a block" unless block_given?

          ShapeDsl.new(self).instance_eval(&block)
        end

        # `strategies do; on(:cond) { prefer :action }; end` block —
        # adaptation guidance (PLAN_0_2_0 Phase C). Each `on(:sym)`
        # call registers a handler that the runtime evaluates against
        # the evidence slice to decide which prompt-construction
        # policy to use.
        #
        # **Advisory, not contract-bearing.** Strategies do NOT appear
        # in `Contract#ensures` and do NOT influence
        # `contracts_satisfied?`. They adjust *which prompts get
        # sent*, not *which outputs are accepted*. The
        # `shape.prohibited:` invariants hold regardless of which
        # strategy fires.
        def strategies(&block)
          guard_unfrozen!(:strategies)
          raise ArgumentError, "strategies requires a block" unless block_given?

          StrategiesDsl.new(self).instance_eval(&block)
        end

        # Freeze and return the Contract. Memoized — subsequent calls
        # return the same frozen instance, and further DSL calls
        # raise `ContractFrozen`.
        def compile
          @contract ||= Contract.new(
            program_class: self,
            requires:      _requires.dup,
            ensures:       _ensures.dup,
            prohibited:    _prohibited.dup,
            strategies:    _strategies.dup,
          ).tap(&:freeze!)
        end

        # Test-only escape hatch. Subclasses created mid-spec
        # accumulate state that another spec can observe; the
        # round-trip integration spec uses anonymous Program
        # subclasses, so this is rarely needed. Not part of the
        # public API.
        def _reset!
          @contract    = nil
          @_requires   = nil
          @_ensures    = nil
          @_prohibited = nil
          @_strategies = nil
        end

        def _strategies; @_strategies ||= {}; end

        private

        def _requires;   @_requires   ||= []; end
        def _ensures;    @_ensures    ||= []; end
        def _prohibited; @_prohibited ||= []; end

        def guard_unfrozen!(clause)
          return unless defined?(@contract) && @contract

          raise ::Vv::Learn::Errors::ContractFrozen,
                "#{name || '(anonymous Program)'}: cannot append " \
                "#{clause} after .compile — contracts are frozen at " \
                "compile time (no-backwards-compat invariant)."
        end
      end

      # The `shape do ... end` block's instance context. Exists so
      # `prohibited :sym` reads naturally inside the block without
      # leaking the helper outside.
      class ShapeDsl
        def initialize(program_class)
          @program_class = program_class
        end

        def prohibited(symbol)
          @program_class.send(:_prohibited) << symbol
        end
      end

      # The `strategies do ... end` block's instance context. The
      # `on(:cond) { prefer :action }` pattern reads naturally
      # inside the block. The inner `prefer :action` lives on a
      # second tiny DSL (`StrategyHandlerDsl`) so the user's block
      # captures the action symbol without surrounding ceremony.
      class StrategiesDsl
        def initialize(program_class)
          @program_class = program_class
        end

        def on(condition_symbol, &handler)
          raise ArgumentError, "strategies.on requires a block" unless block_given?

          @program_class._strategies[condition_symbol] = handler
        end
      end

      # The `on(:cond) { prefer :action }` block's instance context.
      # The runtime invokes the handler with `instance_exec` against
      # an instance of this class; `prefer :action` records the
      # action symbol. Strategies returning multiple `prefer` calls
      # are not supported in v0.2.0 — last write wins, documented
      # behaviour.
      class StrategyHandlerDsl
        attr_reader :preferred_action

        def prefer(action_symbol)
          @preferred_action = action_symbol
        end
      end
    end
  end
end
