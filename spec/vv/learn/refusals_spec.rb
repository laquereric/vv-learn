# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Learn::Refusals do
  describe "REGISTRY" do
    it "is frozen at load time" do
      expect(described_class::REGISTRY).to be_frozen
    end

    it "pins the v0.1.0 refusal symbols" do
      expect(described_class::REGISTRY.keys).to contain_exactly(
        :bypass_shacl_pre_validation,
        :publish_without_committer,
        :widen_gold_without_curator_evidence,
      )
    end
  end

  describe ".check!" do
    let(:program) do
      Class.new(Vv::Learn::Program) do
        shape do
          prohibited :bypass_shacl_pre_validation
        end
      end
    end
    let(:contract) { program.compile }

    # Minimal fake of vv-memory's Scoped#shacl_validate, returning
    # a Result-monad-shaped object (.success? boolean). The real
    # PREREQ-A facade returns Dry::Monads::Result; we duck-type to
    # avoid pulling dry-monads as a test dep.
    let(:shacl_success) { Struct.new(:success?).new(true) }
    let(:shacl_failure) { Struct.new(:success?).new(false) }

    let(:scope_passing_shacl) do
      Class.new do
        def initialize(result); @result = result; end
        def shacl_validate(_diff); @result; end
      end.new(shacl_success)
    end

    let(:scope_failing_shacl) do
      Class.new do
        def initialize(result); @result = result; end
        def shacl_validate(_diff); @result; end
      end.new(shacl_failure)
    end

    it "returns :ok when every refusal allows the action" do
      expect(
        described_class.check!(contract, scope: scope_passing_shacl, diff: :anything),
      ).to eq(:ok)
    end

    it "raises ProhibitedAction naming the tripped symbol" do
      expect do
        described_class.check!(contract, scope: scope_failing_shacl, diff: :anything)
      end.to raise_error(Vv::Learn::Errors::ProhibitedAction) do |err|
        expect(err.refusal).to eq(:bypass_shacl_pre_validation)
        expect(err.message).to match(/No model tokens were spent/)
      end
    end

    it "asserts zero model interactions occurred on refusal" do
      # The load-bearing invariant — the spy model is never even
      # constructed. We can prove this directly: `check!` is the
      # only thing called, and it raises before the runtime would
      # build a ModelDispatcher.
      spy_model = Class.new do
        attr_reader :sample_count
        def initialize; @sample_count = 0; end
        def sample(prompt:); @sample_count += 1; "completion"; end
      end.new

      expect do
        described_class.check!(contract, scope: scope_failing_shacl, diff: :anything)
      end.to raise_error(Vv::Learn::Errors::ProhibitedAction)

      expect(spy_model.sample_count).to eq(0)
    end

    it "raises ProhibitedAction with a clear message for an unknown refusal symbol" do
      bad_program = Class.new(Vv::Learn::Program) do
        shape { prohibited :not_a_real_refusal }
      end

      expect do
        described_class.check!(bad_program.compile)
      end.to raise_error(Vv::Learn::Errors::ProhibitedAction, /Unknown refusal symbol/) do |err|
        expect(err.refusal).to eq(:not_a_real_refusal)
      end
    end

    it "raises ProhibitedAction when the runtime doesn't supply required kwargs" do
      # The bypass_shacl_pre_validation lambda requires scope: and
      # diff:. If the runtime omits them, the lambda would raise
      # ArgumentError — check! catches that and re-raises as
      # ProhibitedAction so the operator sees a single error class.
      expect do
        described_class.check!(contract) # nothing passed
      end.to raise_error(Vv::Learn::Errors::ProhibitedAction, /requires keyword arguments/)
    end
  end

  describe "publish_without_committer checker" do
    it "allows turns with a nil committer_ref" do
      turn = Struct.new(:committer_ref).new(nil)
      result = described_class::REGISTRY.fetch(:publish_without_committer).call(turn: turn)
      expect(result).to be(true)
    end

    it "refuses turns with a non-nil committer_ref" do
      turn = Struct.new(:committer_ref).new("operator:alice")
      result = described_class::REGISTRY.fetch(:publish_without_committer).call(turn: turn)
      expect(result).to be(false)
    end
  end

  describe "widen_gold_without_curator_evidence checker" do
    let(:checker) do
      described_class::REGISTRY.fetch(:widen_gold_without_curator_evidence)
    end

    it "passes vacuously when the diff doesn't touch Gold" do
      diff = Struct.new(:touches_gold?, :has_curator_evidence?).new(false, false)
      expect(checker.call(diff: diff)).to be(true)
    end

    it "passes when Gold is touched and curator evidence is present" do
      diff = Struct.new(:touches_gold?, :has_curator_evidence?).new(true, true)
      expect(checker.call(diff: diff)).to be(true)
    end

    it "refuses when Gold is touched without curator evidence" do
      diff = Struct.new(:touches_gold?, :has_curator_evidence?).new(true, false)
      expect(checker.call(diff: diff)).to be(false)
    end

    it "passes when the diff object doesn't implement touches_gold?" do
      # Defensive: a diff value that has nothing to do with Gold
      # (e.g., a plain string for an ontology-only TURN) must not
      # trip this refusal.
      expect(checker.call(diff: "any diff value")).to be(true)
    end
  end
end
