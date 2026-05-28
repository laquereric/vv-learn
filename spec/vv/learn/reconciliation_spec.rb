# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Learn::Reconciliation do
  describe Vv::Learn::Reconciliation::Perspective do
    let(:valid_args) do
      {
        actor: :extractor_v3,
        predicate: "mm:status",
        object: '"open"',
        confidence: 0.82,
      }
    end

    it "constructs with well-formed keyword arguments" do
      perspective = described_class.new(**valid_args)
      expect(perspective.actor).to eq(:extractor_v3)
      expect(perspective.predicate).to eq("mm:status")
      expect(perspective.object).to eq('"open"')
      expect(perspective.confidence).to eq(0.82)
    end

    it "is a frozen Data instance" do
      perspective = described_class.new(**valid_args)
      expect(perspective).to be_frozen
    end

    it "raises ArgumentError when actor is not a Symbol" do
      expect { described_class.new(**valid_args.merge(actor: "extractor_v3")) }
        .to raise_error(ArgumentError, /actor must be a Symbol/)
    end

    it "raises ArgumentError when predicate is empty or non-String" do
      expect { described_class.new(**valid_args.merge(predicate: "")) }
        .to raise_error(ArgumentError, /predicate must be a non-empty String/)
      expect { described_class.new(**valid_args.merge(predicate: 42)) }
        .to raise_error(ArgumentError, /predicate must be a non-empty String/)
    end

    it "raises ArgumentError when object is empty or non-String" do
      expect { described_class.new(**valid_args.merge(object: "")) }
        .to raise_error(ArgumentError, /object must be a non-empty String/)
    end

    it "raises ArgumentError when confidence is out of [0.0, 1.0]" do
      expect { described_class.new(**valid_args.merge(confidence: -0.1)) }
        .to raise_error(ArgumentError, /confidence must be Numeric in \[0\.0, 1\.0\]/)
      expect { described_class.new(**valid_args.merge(confidence: 1.5)) }
        .to raise_error(ArgumentError, /confidence must be Numeric in \[0\.0, 1\.0\]/)
      expect { described_class.new(**valid_args.merge(confidence: "0.5")) }
        .to raise_error(ArgumentError, /confidence must be Numeric in \[0\.0, 1\.0\]/)
    end
  end

  describe "RESOLUTIONS" do
    it "pins the v0.2.0 resolution symbols" do
      expect(described_class::RESOLUTIONS).to contain_exactly(
        :widen_ontology_with_skos_alt_label,
        :prefer_higher_confidence,
        :defer_to_curator,
        :request_extractor_revision,
      )
    end

    it "is frozen at load time" do
      expect(described_class::RESOLUTIONS).to be_frozen
    end
  end

  describe ".validate_inputs!" do
    let(:p1) do
      described_class::Perspective.new(
        actor: :extractor_v3, predicate: "mm:status",
        object: '"open"', confidence: 0.82,
      )
    end
    let(:p2) do
      described_class::Perspective.new(
        actor: :extractor_v4, predicate: "mm:status",
        object: '"reopened"', confidence: 0.78,
      )
    end
    let(:prose) do
      "Two extractor revisions disagree about order 42's status " \
      "across the same Bronze episode. v3 reads the open literal; " \
      "v4 reads the reopened element."
    end

    it "returns :ok with well-formed inputs" do
      expect(
        described_class.validate_inputs!(
          perspectives:           [p1, p2],
          describe_unambiguously: prose,
          proposed_resolution:    :widen_ontology_with_skos_alt_label,
        ),
      ).to eq(:ok)
    end

    it "requires at least 2 perspectives" do
      expect do
        described_class.validate_inputs!(
          perspectives:           [p1],
          describe_unambiguously: prose,
          proposed_resolution:    :widen_ontology_with_skos_alt_label,
        )
      end.to raise_error(ArgumentError, /at least 2 perspectives/)
    end

    it "requires perspectives to be Perspective instances" do
      expect do
        described_class.validate_inputs!(
          perspectives:           [p1, { actor: :v4, predicate: "x", object: "y", confidence: 0.5 }],
          describe_unambiguously: prose,
          proposed_resolution:    :widen_ontology_with_skos_alt_label,
        )
      end.to raise_error(ArgumentError, /must all be.+Perspective/)
    end

    it "requires distinct actors across perspectives" do
      dup = described_class::Perspective.new(
        actor: :extractor_v3, predicate: "mm:status",
        object: '"closed"', confidence: 0.7,
      )

      expect do
        described_class.validate_inputs!(
          perspectives:           [p1, dup],
          describe_unambiguously: prose,
          proposed_resolution:    :widen_ontology_with_skos_alt_label,
        )
      end.to raise_error(ArgumentError, /distinct actors/)
    end

    it "requires describe_unambiguously prose of MIN_DESCRIPTION_LENGTH chars" do
      expect do
        described_class.validate_inputs!(
          perspectives:           [p1, p2],
          describe_unambiguously: "too short",
          proposed_resolution:    :widen_ontology_with_skos_alt_label,
        )
      end.to raise_error(ArgumentError, /at least #{described_class::MIN_DESCRIPTION_LENGTH} characters/)
    end

    it "requires proposed_resolution to be in RESOLUTIONS" do
      expect do
        described_class.validate_inputs!(
          perspectives:           [p1, p2],
          describe_unambiguously: prose,
          proposed_resolution:    :not_a_real_resolution,
        )
      end.to raise_error(ArgumentError, /proposed_resolution must be one of/)
    end
  end

  describe ".description_discriminates?" do
    let(:p1) do
      described_class::Perspective.new(
        actor: :extractor_v3, predicate: "mm:status",
        object: '"open"', confidence: 0.82,
      )
    end
    let(:p2) do
      described_class::Perspective.new(
        actor: :extractor_v4, predicate: "mm:status",
        object: '"reopened"', confidence: 0.78,
      )
    end

    it "returns true when the prose names every actor symbol AND object literal" do
      prose = 'extractor_v3 sees "open" but extractor_v4 sees "reopened" — vocabulary gap.'
      expect(
        described_class.description_discriminates?(perspectives: [p1, p2], describe_unambiguously: prose),
      ).to be(true)
    end

    it "returns false when an actor symbol is missing from the prose" do
      prose = '"open" vs "reopened" — vocabulary gap; extractor_v3 is one source.'
      # missing :extractor_v4
      expect(
        described_class.description_discriminates?(perspectives: [p1, p2], describe_unambiguously: prose),
      ).to be(false)
    end

    it "returns false when an object literal is missing from the prose" do
      prose = "extractor_v3 and extractor_v4 disagree but the prose is generic."
      expect(
        described_class.description_discriminates?(perspectives: [p1, p2], describe_unambiguously: prose),
      ).to be(false)
    end
  end

  describe ".open" do
    let(:p1) do
      described_class::Perspective.new(
        actor: :extractor_v3, predicate: "mm:status",
        object: '"open"', confidence: 0.82,
      )
    end
    let(:p2) do
      described_class::Perspective.new(
        actor: :extractor_v4, predicate: "mm:status",
        object: '"reopened"', confidence: 0.78,
      )
    end
    let(:prose) do
      "Two extractor revisions disagree about order 42's status " \
      "across the same Bronze episode. v3 reads the open literal; " \
      "v4 reads the reopened element."
    end

    it "raises RuntimeNotReady when Vv::Learn.run! is undefined (v0.1.0 Phase C deferred)" do
      # Vv::Learn.run! does not exist yet — its v0.1.0 Phase C body
      # is blocked on PREREQ-A/B/C in sibling gems. .open should
      # raise the typed RuntimeNotReady error, NOT NoMethodError,
      # so operators see a clear deferral signal.
      expect(::Vv::Learn).not_to respond_to(:run!)

      expect do
        described_class.open(
          scope:                  Object.new,
          perspectives:           [p1, p2],
          describe_unambiguously: prose,
          proposed_resolution:    :widen_ontology_with_skos_alt_label,
          model:                  Object.new,
        )
      end.to raise_error(Vv::Learn::Errors::RuntimeNotReady, /v0\.1\.0 Phase C/)
    end

    it "validates inputs BEFORE checking runtime readiness (ArgumentError takes precedence)" do
      # Operators with malformed inputs should see the input
      # error, not the RuntimeNotReady error. The validation
      # discipline is the surface that works today.
      expect do
        described_class.open(
          scope:                  Object.new,
          perspectives:           [p1], # only 1 — should fail validation
          describe_unambiguously: prose,
          proposed_resolution:    :widen_ontology_with_skos_alt_label,
          model:                  Object.new,
        )
      end.to raise_error(ArgumentError, /at least 2 perspectives/)
    end
  end

  describe Vv::Learn::Reconciliation::ReconciliationProgram do
    it "compiles a frozen contract with the v0.2.0 ensures additions" do
      contract = described_class.compile
      expect(contract).to be_frozen
      expect(contract.ensures).to include(:perspectives_named, :description_discriminates)
      expect(contract.requires.map { |r| r[:name] }).to contain_exactly(
        :perspectives,
        :unambiguous_description,
        :proposed_resolution,
      )
      expect(contract.prohibited).to contain_exactly(
        :bypass_shacl_pre_validation,
        :publish_without_committer,
      )
    end
  end
end
