# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Learn::Program do
  # Each example defines an anonymous subclass so accumulated DSL
  # state doesn't leak across examples.

  describe ".compile" do
    it "freezes the contract on first call and memoizes" do
      program = Class.new(described_class) do
        requires :scope
        requires :evidence_window, default: 86_400
        ensures  :turn_filed
        shape do
          prohibited :bypass_shacl_pre_validation
        end
      end

      contract = program.compile

      expect(contract).to be_frozen
      expect(contract.requires).to be_frozen
      expect(contract.ensures).to be_frozen
      expect(contract.prohibited).to be_frozen
      expect(contract.strategies).to be_frozen
      expect(contract.strategies).to eq({})
      expect(contract.program_class).to eq(program)
      expect(contract.requires).to eq([
        { name: :scope, default: described_class::REQUIRED },
        { name: :evidence_window, default: 86_400 },
      ])
      expect(contract.ensures).to eq([:turn_filed])
      expect(contract.prohibited).to eq([:bypass_shacl_pre_validation])

      # Memoization: same instance back.
      expect(program.compile).to equal(contract)
    end

    it "raises ContractFrozen when DSL methods are called post-compile" do
      program = Class.new(described_class) do
        requires :scope
      end
      program.compile

      expect { program.requires(:added_later) }
        .to raise_error(Vv::Learn::Errors::ContractFrozen, /requires/)
      expect { program.ensures(:added_later) }
        .to raise_error(Vv::Learn::Errors::ContractFrozen, /ensures/)
      expect { program.shape { prohibited :added_later } }
        .to raise_error(Vv::Learn::Errors::ContractFrozen, /shape/)
    end
  end

  describe ".strategies" do
    it "registers handlers under their condition symbols" do
      program = Class.new(described_class) do
        strategies do
          on(:many_low_confidence_silver) { prefer :reconciliation_turn }
          on(:shacl_violations_rising)    { prefer :shape_tightening_turn }
        end
      end
      contract = program.compile

      expect(contract.strategies.keys).to eq(%i[many_low_confidence_silver shacl_violations_rising])
      expect(contract.strategies).to be_frozen
      expect(contract.strategies.values).to all(be_a(Proc))
    end

    it "requires a block" do
      program = Class.new(described_class)

      expect { program.strategies }.to raise_error(ArgumentError, /block/)
    end

    it "requires on(:sym) to receive a block" do
      expect do
        Class.new(described_class) do
          strategies do
            on(:foo) # no block
          end
        end
      end.to raise_error(ArgumentError, /requires a block/)
    end

    it "strategies do NOT appear in Contract#ensures (advisory, not contract-bearing)" do
      program = Class.new(described_class) do
        ensures :turn_filed
        strategies do
          on(:foo) { prefer :bar }
        end
      end
      contract = program.compile

      expect(contract.ensures).to eq([:turn_filed])
      expect(contract.ensures).not_to include(:foo)
    end

    it "handler block records the preferred action via StrategyHandlerDsl" do
      program = Class.new(described_class) do
        strategies do
          on(:cond) { prefer :do_the_thing }
        end
      end
      handler = program.compile.strategies.fetch(:cond)

      dsl = Vv::Learn::Program::StrategyHandlerDsl.new
      dsl.instance_exec(&handler)
      expect(dsl.preferred_action).to eq(:do_the_thing)
    end

    it "raises ContractFrozen when called post-compile" do
      program = Class.new(described_class)
      program.compile

      expect { program.strategies { on(:foo) { prefer :bar } } }
        .to raise_error(Vv::Learn::Errors::ContractFrozen, /strategies/)
    end
  end

  describe ".shape" do
    it "requires a block" do
      program = Class.new(described_class)

      expect { program.shape }.to raise_error(ArgumentError, /block/)
    end

    it "accumulates prohibited symbols in declaration order" do
      program = Class.new(described_class) do
        shape do
          prohibited :a
          prohibited :b
        end
        shape do
          prohibited :c
        end
      end

      expect(program.compile.prohibited).to eq(%i[a b c])
    end
  end

  describe "the REQUIRED sentinel" do
    it "distinguishes a required input from one defaulting to nil" do
      program = Class.new(described_class) do
        requires :must_be_given
        requires :may_be_nil, default: nil
      end
      contract = program.compile

      expect(contract.requires.first[:default]).to equal(described_class::REQUIRED)
      expect(contract.requires.last[:default]).to be_nil
    end

    it "is frozen and has a readable inspect/to_s" do
      expect(described_class::REQUIRED).to be_frozen
      expect(described_class::REQUIRED.inspect).to eq("Vv::Learn::Program::REQUIRED")
    end
  end
end
