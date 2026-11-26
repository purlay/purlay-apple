# The stable entry point. scripts/verify holds the lanes (and `scripts/verify <lane>` runs one); this file only names the sets of
# them people and pipelines ask for.
.PHONY: setup verify verify-security verify-all

# The pinned contract bundle and the pinned scanner. Network.
setup:
	scripts/prepare-contract
	scripts/install-gitleaks

# What a pull request must pass: the rules, format and every package test, and both apps built. No simulator.
verify:
	scripts/verify rules
	scripts/verify packages
	scripts/verify ios
	scripts/verify macos

# The history scanned for secrets (needs the full clone).
verify-security:
	scripts/verify security

# Every lane, as a release runs them: the generated code, the Mac's Release build and the simulator included.
verify-all:
	scripts/verify
