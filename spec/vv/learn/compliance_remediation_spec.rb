# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Learn::ComplianceRemediation do
  let(:violation) do
    described_class::Violation.new(
      gate:    "cr-audit",
      member:  "vendor/vv-web",
      detail:  "CONSUMER_REQUIREMENT_VV_WEB.md missing PINNED markers",
      surface: "CONSUMER_REQUIREMENT_*.md",
    )
  end

  describe described_class::Violation do
    it "constructs with all four non-empty Strings" do
      v = described_class.new(
        gate: "g", member: "m", detail: "d", surface: "s"
      )
      expect(v.gate).to eq("g")
      expect(v.surface).to eq("s")
    end

    it "raises ArgumentError on any empty field" do
      expect { described_class.new(gate: "", member: "m", detail: "d", surface: "s") }
        .to raise_error(ArgumentError, /gate must be a non-empty String/)
      expect { described_class.new(gate: "g", member: "", detail: "d", surface: "s") }
        .to raise_error(ArgumentError, /member must be a non-empty String/)
      expect { described_class.new(gate: "g", member: "m", detail: "", surface: "s") }
        .to raise_error(ArgumentError, /detail must be a non-empty String/)
      expect { described_class.new(gate: "g", member: "m", detail: "d", surface: "") }
        .to raise_error(ArgumentError, /surface must be a non-empty String/)
    end
  end

  describe ".validate_inputs!" do
    it "returns :ok with well-formed inputs" do
      expect(described_class.validate_inputs!(violations: [violation])).to eq(:ok)
    end

    it "requires at least one violation" do
      expect { described_class.validate_inputs!(violations: []) }
        .to raise_error(ArgumentError, /at least 1 violation/)
    end

    it "requires every violation to be a Violation" do
      expect { described_class.validate_inputs!(violations: [{ gate: "x" }]) }
        .to raise_error(ArgumentError, /must all be.+Violation/)
    end

    it "requires distinct gate+member keys" do
      dup = described_class::Violation.new(
        gate: "cr-audit", member: "vendor/vv-web",
        detail: "another finding", surface: "*.md"
      )
      expect { described_class.validate_inputs!(violations: [violation, dup]) }
        .to raise_error(ArgumentError, /distinct.+gate\+member/)
    end

    it "permits the same gate on a different member" do
      other = described_class::Violation.new(
        gate: "cr-audit", member: "vendor/vv-graph",
        detail: "missing section", surface: "*.md"
      )
      expect(described_class.validate_inputs!(violations: [violation, other])).to eq(:ok)
    end
  end

  describe ".instructions_for" do
    it "names the gate, member, and surface; says minimal fix" do
      text = described_class.instructions_for(violation: violation)
      expect(text).to include("cr-audit")
      expect(text).to include("vendor/vv-web")
      expect(text).to include("CONSUMER_REQUIREMENT_*.md")
      expect(text).to match(/minimal fix/i)
      expect(text).to match(/never\s+force-push/i)
    end
  end

  # Mirrors the CrReconciliation lockstep block: vv-agent's Task.run!
  # REQUIRES scope: + provider:; this pins the call-site ↔ Task.run!
  # contract so the required surface can't silently drift.
  describe ".open — Vv::Agent::Task.run! dispatch lockstep" do
    it "raises RuntimeNotReady when the vv-agent Task runtime is absent" do
      # Standalone spec env does not load vv-agent.
      expect(defined?(::Vv::Agent::Task)).to be_nil
      expect do
        described_class.open(violations: [violation], scope: Object.new)
      end.to raise_error(Vv::Learn::Errors::RuntimeNotReady, /Vv::Agent::Task\.run!/)
    end

    it "validates inputs BEFORE the runtime check (ArgumentError takes precedence)" do
      expect do
        described_class.open(violations: [], scope: Object.new)
      end.to raise_error(ArgumentError, /at least 1 violation/)
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

      it "passes the REQUIRED scope:/provider:/instructions:/provenance_id:" do
        scope = Object.new
        described_class.open(violations: [violation], scope: scope)

        kw = captured.first
        expect(kw).to include(:scope, :provider, :instructions, :provenance_id)
        expect(kw[:scope]).to be(scope)
        # BYO-resolved through Vv::Agent.select — never a hardwired model.
        expect(kw[:provider]).to eq(:byo_resolved_provider)
        expect(kw[:instructions]).to include("cr-audit")
        expect(kw[:provenance_id]).to eq("compliance-fix:cr-audit:vendor/vv-web")
      end

      it "lets the caller override the provider (still BYO, not hardwired)" do
        described_class.open(violations: [violation], scope: Object.new, provider: :explicit)
        expect(captured.first[:provider]).to eq(:explicit)
      end

      it "is non-halting: a failing violation is collected, not raised" do
        allow(::Vv::Agent::Task).to receive(:run!).and_raise(RuntimeError, "boom")
        results = described_class.open(violations: [violation], scope: Object.new)
        expect(results.first).to include(gate: "cr-audit", member: "vendor/vv-web", ok: false)
        expect(results.first[:detail]).to match(/RuntimeError: boom/)
      end
    end
  end

  describe described_class::ComplianceProgram do
    let(:contract) { described_class.compile }

    it "compiles a frozen contract with the right requires/ensures" do
      expect(contract).to be_frozen
      expect(contract.requires.map { |r| r[:name] }).to contain_exactly(:gate, :member)
      expect(contract.ensures).to contain_exactly(:gate_green)
    end

    it "gates EXACTLY the dangerous remediations — the complete human-decision set" do
      expect(contract.prohibited).to contain_exactly(
        :edit_outside_violating_surface,
        :unnecessary_code_changes,
        :commit_in_mm_boundary,
        :force_push_over_newer_remote,
      )
    end
  end
end
