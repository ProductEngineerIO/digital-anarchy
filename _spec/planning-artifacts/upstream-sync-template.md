# Upstream Sync — Runbook

> How to catch the fork up with `upstream/main` (koala73/worldmonitor). This process produces a tracked epic with 6 stories. Run it whenever the fork falls behind.

## Prerequisites

- Git remote `upstream` points to `https://github.com/koala73/worldmonitor.git`
- You're on the `develop` branch
- Working tree is clean (`git status` shows nothing)

Verify with:

```bash
git remote -v | grep upstream
# Should show: upstream  https://github.com/koala73/worldmonitor.git
```

---

## Step 1: Assess the Gap

Fetch and measure how far behind you are.

```bash
git fetch upstream

# How many commits behind?
git log --oneline develop..upstream/main | wc -l

# PR number range
git log --oneline develop..upstream/main | grep -Eo '#[0-9]+' | sed 's/#//' | sort -n | head -1  # oldest
git log --oneline develop..upstream/main | grep -Eo '#[0-9]+' | sed 's/#//' | sort -n | tail -1  # newest

# Commit type breakdown (feat/fix/refactor/perf/chore/docs/test)
git log --oneline develop..upstream/main | sed 's/^[a-f0-9]* //' \
  | grep -Eoi '^(feat|fix|refactor|perf|chore|docs|test)' \
  | sort | uniq -c | sort -rn

# Domain/scope breakdown
git log --oneline develop..upstream/main | sed 's/^[a-f0-9]* //' \
  | grep -Eoi '^(feat|fix|refactor|perf|chore|docs|test)\([^)]*\)' \
  | sed 's/.*(\(.*\)).*/\1/' \
  | sort | uniq -c | sort -rn

# Overall file change stats
git diff --stat develop..upstream/main | tail -5

# List all new features
git log --oneline develop..upstream/main | grep -i 'feat' | head -60

# Recent commits (newest first)
git log --oneline develop..upstream/main | head -40

# Oldest commits (what we missed first)
git log --oneline develop..upstream/main | tail -40
```

---

## Step 2: Generate the Epic

Ask Copilot (or do manually):

> "Pull latest from fork. Then write epic/story to integrate new changes from fork into this repo."

This produces a file at `_spec/implementation-artifacts/epic-upstream-sync-{date}.md` containing:

- Change summary by domain
- Risk assessment
- 6 stories (described below)

---

## Step 3: Register in Sprint Tracking

**Add to `_spec/implementation-artifacts/sprint-status.yaml`:**

```yaml
  # ── Upstream Sync: {Month} {Year} (PRs #{first}–#{last}) ──
  epic-upstream-sync-{date}: backlog
  S-1-merge-branch-conflict-resolution: backlog
  S-2-build-validation-proto-check: backlog
  S-3-env-var-audit-configuration: backlog
  S-4-fork-hook-branding-validation: backlog
  S-5-e2e-smoke-test-pass: backlog
  S-6-merge-develop-preview-deploy: backlog
  epic-upstream-sync-{date}-retrospective: optional
```

**Add to `_spec/planning-artifacts/epics.md`** under "Recurring: Upstream Sync Epics":

```markdown
### Upstream Sync — {Month} {Year} (PRs #{first}–#{last})
**Implementation Artifact:** `_spec/implementation-artifacts/epic-upstream-sync-{date}.md`
**Stories:** S-1 through S-6
**Scope:** {count} commits, {files} files changed
```

---

## Step 4: Execute the 6 Stories

### S-1: Create Sync Branch & Resolve Merge Conflicts

```bash
git checkout develop
git checkout -b upstream-sync/{date}
git merge upstream/main
# Resolve conflicts...
```

**Critical checkpoints:**
- `src/main.ts` — fork hook import (`src/fork/index`) must survive (ARCH-37)
- `package.json` — keep fork deps, accept upstream additions
- `vite.config.ts` — merge upstream changes (e.g., dynamic env loading)
- `vercel.json` — merge route/rewrite changes
- `middleware.ts` — merge edge middleware changes

```bash
npm install        # verify clean install
make generate      # verify proto codegen
```

**Commit prefix:** `[sync] merge upstream vX.Y.Z (PRs #{first}–#{last})`

### S-2: Build Validation & Proto Check (after S-1)

```bash
make lint          # record new warnings vs baseline
make build         # VITE_VARIANT=full must succeed
buf breaking       # no breaking proto changes
node --test        # unit tests pass
```

### S-3: Env Var Audit (parallel with S-2)

```bash
# Find new env var references compared to fork baseline
git diff develop..upstream-sync/{date} -- '*.ts' '*.js' '*.mjs' \
  | grep -E '\+.*process\.env\.|import\.meta\.env\.' \
  | grep -v '@@' | sort -u

# Find new Redis key patterns
git diff develop..upstream-sync/{date} -- 'server/' 'scripts/' \
  | grep -E '\+.*redis|upstash|REDIS' \
  | grep -v '@@' | sort -u
```

- Update `fork.env.example` with new variables
- Document new Railway seed services
- Verify all Redis keys use `prefixedKey()` (ARCH-29)

### S-4: Fork Hook & Branding Validation (after S-2)

```bash
make dev           # start dev server
```

Verify manually:
- Fork hook executes (no `[fork] ...` console warnings)
- Situation Monitor branding: page title, meta tags, favicon
- New panels inherit `--sm-*` CSS tokens (spot check ≥5 new panels)
- Globe, map layers, settings UI intact
- CLS = 0

### S-5: E2E & Smoke Tests (after S-4)

```bash
npx playwright test              # E2E suite
scripts/validate-endpoints.sh    # endpoint smoke test (if available)
```

Catalog new test files from upstream in `e2e/`.

### S-6: Merge to Develop & Deploy (after S-5)

```bash
# Push sync branch and open PR
git push origin upstream-sync/{date}
# Open PR: upstream-sync/{date} → develop
# Wait for CI to pass
# Merge
# Verify Vercel Preview deployment loads
```

---

## Architecture References

| Rule | What |
|------|------|
| ARCH-34 | Upstream sync uses dedicated `upstream-sync` branch pattern |
| ARCH-37 | Post-merge checklist: verify fork hook, run `make generate`, resolve `package.json`, full test suite |
| ARCH-38 | Run `make generate` after every upstream merge; catch codegen tool changes |
| ARCH-29 | Redis keys must use `prefixedKey()` wrapper |
| ARCH-4 | Fork only deploys `VITE_VARIANT=full` |
| ARCH-24 | Upstream syncs use `[sync] merge upstream vX.Y.Z` commit prefix |

---

## Past Syncs

| Date | PR Range | Commits | Epic File |
|------|----------|---------|-----------|
| 2026-03-18 | #809–#1851 | 648 | `_spec/implementation-artifacts/epic-upstream-sync-march-2026.md` |
