# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Learn::CrReconciliation do
  let(:target) do
    described_class::Target.new(name: "vv-web", path: "vendor/vv-web")
  end
  let(:plans) { ["docs/plans/PLAN_0_93_1.md", "docs/plans/PLAN_0_93_2.md"] }

  describe described_class::Target do
    it "constructs with a default cr_glob" do
      t = described_class.new(name: "vv-web", path: "vendor/vv-web")
      expect(t.cr_glob).to eq("CONSUMER_REQUIREMENT_*.md")
    end

    it "raises ArgumentError on empty name/path" do
      expect { described_class.new(name: "", path: "x") }
        .to raise_error(ArgumentError, /name must be a non-empty String/)
      expect { described_class.new(name: "x", path: "") }
        .to raise_error(ArgumentError, /path must be a non-empty String/)
    end
  end

  describe ".validate_inputs!" do
    it "returns :ok with well-formed inputs" do
      expect(described_class.validate_inputs!(targets: [target], plans: plans)).to eq(:ok)
    end

    it "requires at least one target" do
      expect { described_class.validate_inputs!(targets: [], plans: plans) }
        .to raise_error(ArgumentError, /at least 1 target/)
    end

    it "requires every target to be a Target" do
      expect { described_class.validate_inputs!(targets: [{ name: "x" }], plans: plans) }
        .to raise_error(ArgumentError, /must all be.+Target/)
    end

    it "requires distinct target names" do
      dup = described_class::Target.new(name: "vv-web", path: "elsewhere")
      expect { described_class.validate_inputs!(targets: [target, dup], plans: plans) }
        .to raise_error(ArgumentError, /distinct names/)
    end

    it "requires a non-empty Array of plan paths" do
      expect { described_class.validate_inputs!(targets: [target], plans: []) }
        .to raise_error(ArgumentError, /non-empty Array of plan/)
    end
  end

  describe ".instructions_for" do
    it "names the target, its cr_glob, and the plans; forbids code/out-of-scope" do
      text = described_class.instructions_for(target: target, plans: plans)
      expect(text).to include("vv-web")
      expect(text).to include("CONSUMER_REQUIREMENT_*.md")
      expect(text).to include("PLAN_0_93_1.md")
      expect(text).to match(/change no code/i)
    end
  end

  # The drift the parallel CR-reconciliation pass caught: vv-agent's
  # Task.run! REQUIRES scope: + provider:, but .open had been calling it
  # without them — so the moment the readiness guard passed, dispatch
  # would fail. This block pins the call-site ↔ Task.run! lockstep so the
  # required surface can't silently drift again.
  describe ".open — Vv::Agent::Task.run! dispatch lockstep" do
    it "raises RuntimeNotReady when the vv-agent Task runtime is absent" do
      # Standalone spec env does not load vv-agent.
      expect(defined?(::Vv::Agent::Task)).to be_nil
      expect do
        described_class.open(targets: [target], plans: plans, scope: Object.new)
      end.to raise_error(Vv::Learn::Errors::RuntimeNotReady, /Vv::Agent::Task\.run!/)
    end

    it "validates inputs BEFORE the runtime check (ArgumentError takes precedence)" do
      expect do
        described_class.open(targets: [], plans: plans, scope: Object.new)
      end.to raise_error(ArgumentError, /at least 1 target/)
    end

    context "with a stubbed vv-agent runtime" do
      let(:captured) { [] }

      before do
        cap = captured
        stub_const("Vv::Agent", Module.new do
          define_singleton_method(:select) { |required:, prefer:| :byo_resolved_provider }
        end)
        task = Class.new do
          define_singleton_method(:run!) { |**kw| cap << kw; :ran }
        end
        stub_const("Vv::Agent::Task", task)
      end

      it "passes the REQUIRED scope: and provider: that Task.run! demands" do
        scope = Object.new
        described_class.open(targets: [target], plans: plans, scope: scope)

        kw = captured.first
        # The two kwargs whose absence was the drift:
        expect(kw).to include(:scope, :provider, :instructions, :provenance_id)
        expect(kw[:scope]).to be(scope)
        # BYO-resolved through Vv::Agent.select — never a hardwired model.
        expect(kw[:provider]).to eq(:byo_resolved_provider)
        expect(kw[:provenance_id]).to eq("cr-reconcile:vv-web")
      end

      it "lets the caller override the provider (still BYO, not hardwired)" do
        described_class.open(targets: [target], plans: plans, scope: Object.new, provider: :explicit)
        expect(captured.first[:provider]).to eq(:explicit)
      end

      it "is non-halting: a failing target is collected, not raised" do
        allow(::Vv::Agent::Task).to receive(:run!).and_raise(RuntimeError, "boom")
        results = described_class.open(targets: [target], plans: plans, scope: Object.new)
        expect(results.first).to include(target: "vv-web", ok: false)
        expect(results.first[:detail]).to match(/RuntimeError: boom/)
      end
    end
  end

  # Encodes the operator's standing authorization. During reconciliation
  # the operator answered "yes" to routine in-scope (sed-style) doc edits
  # many times. That standing yes is pinned as a contract invariant: the
  # `prohibited:` set is the COMPLETE human gate; routine edits to a sub's
  # own CONSUMER_REQUIREMENT_* files are pre-authorized, so the autonomous
  # loop performs them without re-prompting. Only the dangerous actions
  # below ever require a human decision.
  describe described_class::CrReconciliationProgram do
    let(:contract) { described_class.compile }

    it "compiles a frozen contract" do
      expect(contract).to be_frozen
      expect(contract.requires.map { |r| r[:name] }).to contain_exactly(:targets, :plans)
      expect(contract.ensures).to contain_exactly(
        :cr_reconciled, :committed_in_sub_boundary, :audit_green
      )
    end

    it "gates EXACTLY the dangerous actions — the complete human-decision set" do
      expect(contract.prohibited).to contain_exactly(
        :edit_outside_cr_files,
        :code_changes,
        :commit_in_mm_boundary,
        :force_push_over_newer_remote,
      )
    end

    it "does NOT prohibit routine in-scope CR edits (the operator's standing yes)" do
      # sed-style edits to the sub's own CONSUMER_REQUIREMENT_* files are
      # the loop's normal work. They are deliberately absent from the
      # prohibited set, so they run autonomously — no per-edit re-approval.
      expect(contract.prohibited).not_to include(:edit_cr_files)
      expect(contract.prohibited).not_to include(:routine_doc_edit)
      expect(contract.prohibited).not_to include(:sed_in_scope)
    end
  end
end
