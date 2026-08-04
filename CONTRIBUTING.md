# Contributing

## Branches

- **Owners** may push directly to `main`.
- **External contributors** use a fork and open a pull request against `main`.
- Do not open long-lived feature branches in the upstream repo unless coordinating with maintainers.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):

| Type | Effect on release |
|------|-------------------|
| `feat:` | minor bump |
| `fix:` | patch bump |
| `feat!:` / `fix!:` / `BREAKING CHANGE:` | major bump |
| `docs:`, `chore:`, `ci:`, `test:`, `refactor:` | no version bump (unless breaking) |

Examples: `feat: add folder output`, `fix(storage): correct bucket ACL`.

## Pull requests

CI (`.github/workflows/ci.yml`) runs on every PR and on every push to `main`:

- Lint job: `terraform fmt` / `validate`, ShellCheck, Hadolint
- Image job: `docker build` + `help` smoke (no registry push)

Fork PRs never receive Docker Hub credentials and never publish images.

CI pulls public base image `stupean/yandex-terraform` (digest-pinned in Dockerfile) without registry login.

## Releases

Releases are **conscious**, not automatic on every `feat`:

1. [release-please](https://github.com/googleapis/release-please) opens or updates a **Release PR** on `main` (version + `CHANGELOG.md` + `version.txt`).
2. Maintainers review and **merge** that PR when ready to publish.
3. On that same `push` to `main`, release-please creates git tag `vX.Y.Z` and a GitHub Release.
4. The **same workflow** (`.github/workflows/release-please.yml`) then calls the composite action `.github/actions/publish-image`, which builds and pushes:
   - `stupean/terraform-yc-bootstrap:X.Y.Z`
   - `stupean/terraform-yc-bootstrap:latest`
   and upserts the image digest into the GitHub Release notes.

Publish is **not** triggered by `push: tags`: tags created with `GITHUB_TOKEN` do not start other workflows. That is intentional.

Until the Release PR is merged, no tag and no Docker Hub publish happen.

Manual rebuild of an already released tag: Actions → **Republish Docker image** (`.github/workflows/docker-publish.yml`). Requires an existing GitHub Release for that tag (so arbitrary tags alone cannot publish). By default **does not** move `latest` (opt-in via `update_latest`) so republishing an older release cannot roll `latest` backward.

### Maintainer setup

Repository secrets (Settings → Secrets and variables → Actions):

| Secret | Purpose |
|--------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub user that can push `stupean/terraform-yc-bootstrap` |
| `DOCKERHUB_TOKEN` | Access token (not account password) with write access |

Recommended branch rules for `main`:

- Restrict who can push: repository owner (+ GitHub Actions for release-please).
- Restrict who can create tags if possible (publish path does not use tag events, but tags still mark releases).
- External contributors: PR only (default for non-collaborators).

Optional later: require CI status checks before merge for everyone.

### First release checklist

1. Add `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets.
2. Push these workflows/config to `main` (or merge the PR that adds them).
3. Wait for **Release Please** to open a Release PR (first published version is expected to be `0.1.0` from bootstrap `0.0.0` + existing conventional commits).
4. Merge the Release PR.
5. Confirm: git tag `v0.1.0` (or next SemVer), GitHub Release, Docker Hub tags `0.1.0` + `latest`, digest in Release notes (same workflow run as release-please).
6. Update README examples to that real version tag or digest.

Bootstrap version files: `.release-please-manifest.json` and `version.txt` start at `0.0.0` so the first Release PR can land on `0.1.0`.
