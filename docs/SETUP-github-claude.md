# Setup: GitHub CI (and adding Claude PR review later)

## CI — already wired up
`.github/workflows/ci.yml` runs on every push to `main` and every PR: it regenerates the Xcode project from `project.yml`, builds, runs all tests, and reports coverage. No setup needed.

## Branch protection — block merging a red build
Free-plan **private** repos can't set branch protection via API. Options:
- **Upgrade to GitHub Pro** (~$4/mo), then:
  ```bash
  gh api -X PUT repos/nikhilc523/bloom/branches/main/protection --input - <<'JSON'
  { "required_status_checks": { "strict": true, "contexts": ["Build & Test"] },
    "enforce_admins": false,
    "required_pull_request_reviews": { "required_approving_review_count": 0 },
    "restrictions": null }
  JSON
  ```
- **Make the repo public** (`gh repo edit --visibility public`) — protection is then free. *Not recommended for a health app.*
- **Or** just adopt the habit: branch → PR → wait for green CI → merge. CI reports on every PR even without enforcement.

## Recommended workflow (enforces "small changes don't break features")
```bash
git switch -c feature/my-change
# ... edit; run tests locally ...
xcodebuild test -project Bloom.xcodeproj -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
git push -u origin feature/my-change
gh pr create --fill        # CI runs automatically
# merge only when CI is green
```

---

## Adding Claude PR review later (currently NOT enabled)
When you're ready for Claude to review every PR, do three things:

1. **Install the Claude GitHub App** — run `/install-github-app` in Claude Code, or visit https://github.com/apps/claude → Install → `nikhilc523/bloom`.
2. **Add the API key secret** — `gh secret set ANTHROPIC_API_KEY` (key from https://console.anthropic.com/).
3. **Re-add the workflow** — create `.github/workflows/claude-code-review.yml`:
   ```yaml
   name: Claude Code Review
   on:
     pull_request:
       types: [opened, synchronize]
   jobs:
     claude-review:
       runs-on: ubuntu-latest
       permissions:
         contents: read
         pull-requests: write
         issues: write
         id-token: write
       steps:
         - uses: actions/checkout@v4
           with: { fetch-depth: 1 }
         - uses: anthropics/claude-code-action@v1
           with:
             anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
             prompt: |
               Review this PR for the Bloom iOS app. Flag only real, high-confidence issues:
               correctness/crashes/force-unwraps, Swift 6 concurrency & SwiftData/CloudKit
               threading, HealthKit auth misuse, and especially PRIVACY/SHARING LEAKS
               (see docs/research/03-partner-sharing-privacy.md), plus missing
               accessibilityIdentifier on new interactive views.
             claude_args: "--max-turns 20"
   ```
   (Just ask Claude Code to "re-add the Claude PR review workflow" and it'll recreate this.)
