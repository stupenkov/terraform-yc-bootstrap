---
name: git-commit
description: >-
  Create git commits on the current branch using Conventional Commits.
  Use when the user asks to commit, create a commit, or write a commit message.
---

# Git Commit

Follow this workflow whenever creating a commit in this repository.

**Always commit on the current branch.** Never create or switch to a topic
branch as part of this skill — the user manages branches themselves.

## Commit message format (Conventional Commits)

```
<type>[optional scope]: <description>

[optional body]
```

| Type | When |
|------|------|
| `feat` | New capability |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Tooling, deps, non-user-facing maintenance |
| `refactor` | Internal restructuring without behavior change |
| `test` | Tests only |
| `ci` | CI / workflow changes |

### Message rules

- Subject: imperative mood, lowercase after the type, no trailing period.
- Focus on **why**, not a file list; 1–2 sentences max in the body if needed.
- Optional scope when useful: `fix(storage):`, `docs(readme):`.
- Match existing history style, e.g. `feat: add Yandex Cloud landing-zone bootstrap with Terraform`.
- Do **not** create empty commits.
- Do **not** commit secrets (`.env`, `*.tfvars` with secrets, key JSON, credentials). Warn if asked to include them.

### Examples

```
feat: add Object Storage bucket for Terraform state

fix: correct folder id variable description

docs: clarify backend bootstrap steps

chore: add terraform.tfvars.example
```

## Commit workflow

Only create a commit when the user explicitly asks to commit.

### 1. Inspect state (run in parallel)

```bash
git status
git diff
git diff --staged
git log -5 --oneline
```

### 2. Draft the message

- Analyze staged + unstaged changes that will be included.
- Choose the correct Conventional Commit `type` (and scope if useful).
- Warn and exclude files that look like secrets.

### 3. Stage and commit (on the current branch)

```bash
git add <relevant-files>
git commit -m "$(cat <<'EOF'
<type>[optional scope]: <description>

EOF
)"
```

Always pass the message via a HEREDOC as above.

### 4. Verify

```bash
git status
```

If a pre-commit hook fails: fix the issue and create a **new** commit. Do not amend unless the amend rules below allow it.

## Git safety protocol

- **Never** update git config.
- **Never** use destructive/irreversible commands (`push --force`, `hard reset`, etc.) unless the user explicitly requests them.
- **Never** skip hooks (`--no-verify`, `--no-gpg-sign`, etc.) unless the user explicitly requests it.
- **Never** force-push to `main`/`master`; warn if asked.
- **Never** use interactive git flags (`-i`, e.g. `rebase -i`, `add -i`).
- **Do not push** unless the user explicitly asks to push.
- **Do not commit** unless the user explicitly asks to commit.
- **Do not create or switch branches** as part of committing.

### Amend — only when all are true

1. User explicitly requested amend, **or** the commit succeeded but a pre-commit hook auto-modified files that must be included.
2. `HEAD` was created by you in this conversation (`git log -1 --format='%an %ae'`).
3. The commit has **not** been pushed (`git status` shows branch ahead of remote).

If the commit failed or was rejected by a hook: **never amend** — fix and make a new commit. If already pushed: **never amend** unless the user explicitly requests it (implies force push).

## Quick checklist

```
- [ ] Committing on current branch (no new branch created)
- [ ] Secrets excluded
- [ ] Message is Conventional Commit
- [ ] HEREDOC used for commit message
- [ ] git status clean for intended files after commit
- [ ] No push unless user asked
```
