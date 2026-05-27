# Remaining Improvements Roadmap

## Implemented in Phase 6 (2026-05-13)

Based on review in `problems.txt` v2 (10 refinement suggestions, targeting 9.0 → 9.5+):

- [x] **State persistence file** — `.firewall-hardening/state.json` with state machine position, backup_dir, rollback_timer_id, plan_hash; 1-hour TTL; advisory-only (defaults to restarting from Detect). **Note**: Schema is documented in SKILL.md § State Persistence — agents must create `$STATE_DIR` and write `state.json` manually. No script auto-generates this yet.
- [x] **Plan JSON schema** — machine-readable PLAN output schema documented in SKILL.md with `add`/`skip`/`remove` arrays, `approval_token`, `risk_assessment`
- [x] **Exit code table moved to SKILL.md** — 15 exit codes (0–61) with agent action columns visible in main document
- [x] **Plan approval gate** — `approval_token` (hash of plan content) required for APPLY; mismatch → exit 41
- [x] **Audit caching** — `firewall-plan.sh` caches `audit-firewall.sh --json` to `/tmp/firewall-audit.json` (TTL 5 min); `--refresh-audit` to force
- [x] **Verify behavior contract** — verify MUST complete within timer window; timeout triggers auto-rollback; verify.sh exits 60, calling agent handles rollback decision
- [x] **Compatibility Matrix** — added Docker host (Full), LXC/LXD (Partial), WSL2 (None) rows
- [x] **Tags restored** — `policy-as-code`, `devsecops`, `ipv6` added back (12 total)
- [x] **Skill version** — `skill_version: 2.1.0`, `schema_version: 2` in frontmatter
- [x] **firewalld/RHEL 9 example session** — added to PUBLISH.md alongside existing ufw example

Score: 9.0+ → 9.5+

Based on review in `problems.txt`:

### Top 1: Split SKILL.md ✓

- [x] SKILL.md slimmed from ~750 to 305 lines. Skeleton only: state machine, decision tree, NEVER DO, quick reference.
- [x] Detailed backend commands moved to separate references:
  - `references/backend-ufw.md`
  - `references/backend-firewalld.md`
  - `references/backend-nftables.md`
  - `references/backend-iptables.md`
- [x] Domain-specific content extracted to:
  - `references/docker-hardening.md`
  - `references/k8s-policy.md`
  - `references/observability.md`
  - `references/compliance.md`
  - `references/recovery.md`

### Top 2: audit-firewall.sh JSON Schema + risk_tier ✓

- [x] Added `risk_tier` field (auto/confirmed/manual/halt) with confidence-based gating
- [x] Added `at_available` and `systemd_run_available` detection
- [x] Rollback capability check reduces confidence by 25 if neither available
- [x] Standardized exit codes defined in `references/special-environments.md`

### Top 3: Plan/dry-run State ✓

- [x] Created `scripts/firewall-plan.sh` — shows what would change before applying
- [x] Supports `--profile`, `--ports`, `--policy-file`, `--json`
- [x] Added PLAN state to SKILL.md state machine
- [x] PLAN output must be reviewed before APPLY when risk_tier = confirmed

### Top 4: When NOT to Use + Special Environments ✓

- [x] Added "When NOT to Use" table to SKILL.md
- [x] Created `references/special-environments.md` covering:
  - Negative trigger conditions
  - Container environments (Docker host vs DinD, rootless, LXC, systemd-nspawn)
  - K8s CNI-specific guidance (Cilium, Calico, Flannel, kube-proxy modes)
  - WSL2 limitations
  - Standardized exit codes table (codes 0–60)

### Top 5: State Persistence + Exit Codes ✓

- [x] Standardized exit codes: 0=SUCCESS, 10-12=BACKEND errors, 20-22=OWNERSHIP/CONTAINER/K8S, 30-31=CONFIDENCE, 40-42=PREFLIGHT, 50-51=APPLY/VERIFY, 60=STATE_FILE
- [x] Exit codes documented in `references/special-environments.md`
- [x] risk_tier provides run-time state gating (replaces need for persistent state file in initial implementation — state file can be added later)

---

## Implemented in Phase 4 (2026-05-11)

- [x] Backend ownership rules — ufw/firewalld active → never touch nftables/iptables directly
- [x] Real rollback scripts — layered restore from backup, dual at/systemd-run support
- [x] audit-firewall.sh --json — machine-readable JSON output
- [x] SSH port exact matching — awk-based to prevent 2222 matching 22
- [x] License — Dual MIT / Apache-2.0
- [x] NEVER DO expanded from 8 to 14 entries
- [x] Docker section overhaul — DOCKER-USER chain deep dive
- [x] Kubernetes section — CNI-specific guidance, audit-only default
- [x] Declarative Policy v2.0 — schema versioning, backend_compat, golden fixtures
- [x] Observability — counters, conntrack, logging, baselines
- [x] Performance risks — conntrack exhaustion, SYN flood, rule ordering
- [x] Compliance mapping — CIS/PCI-DSS/SOC2

## Phase 4 Review Fixes (Late additions)

- [x] Shell expansion safety — `$BACKUP_DIR` quoted, `tee` used for privileged writes
- [x] Outbound policy guidance — explicit DNS/NTP/package mirror checklist
- [x] Backup restore vs emergency ACCEPT — rollback restores backup first, emergency only as fallback
- [x] `nft -c -f` dry-run requirement — mandatory before atomic apply
- [x] Verbose log rate limiting — mandatory limit rate on all log rules

## Future Enhancements (Not yet implemented)

1. **ShellCheck linting** — Add `.shellcheckrc` config and fix warnings in all scripts
2. **State persistence auto-generation** — `firewall-plan.sh` or a dedicated script auto-creates `.firewall-hardening/state.json` (schema in SKILL.md § State Persistence). Currently agents must create it manually.
3. **Bats test suite** — Container-based integration tests per backend
4. **JSON Schema for declarative policy** — `references/policy-schema.json`
5. **Golden output test runner** — Run renderer against fixtures, diff against expected
6. **Cloud security group deep-dive** — AWS CLI, GCP, Azure examples
7. **Geo-restriction module** — `ipset` + country block lists
8. **NetworkPolicy templates for K8s** — YAML templates since host firewall is prohibited
9. **Time-based rules** — Maintenance window auto-enable/disable
10. **SIEM integration** — rsyslog forwarding, journald remote logging
11. **Policy diff tool** — Compare two declarative policies
12. **`hermes skill render-policy` CLI** — Validate and render policy from command line
