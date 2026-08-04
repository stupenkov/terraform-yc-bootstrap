#!/usr/bin/env bash
# Consumer entrypoint for terraform-yc-bootstrap image.
# Usage: docker run ... <image> bootstrap|join|<terraform-args...>
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-/module}"
WORK_DIR="${WORK_DIR:-/work}"

# If the mounted /work looks like this git repo (not an empty work cache),
# do not seed .tf into the checkout root — use a nested gitignored directory.
looks_like_source_checkout() {
  local d="$1"
  [[ -d "${d}/.git" ]] && return 0
  [[ -d "${d}/terraform" && -f "${d}/docker-compose.yml" ]] && return 0
  [[ -f "${d}/Dockerfile" && -d "${d}/scripts" && -d "${d}/openspec" ]] && return 0
  return 1
}

if looks_like_source_checkout "$WORK_DIR"; then
  WORK_DIR="${WORK_DIR}/.yc-bootstrap-work"
  printf '==> Detected source checkout mount; using WORK_DIR=%s\n' "$WORK_DIR"
fi

export MODULE_DIR WORK_DIR

cmd="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$cmd" in
  ""|help|-h|--help)
    cat <<'EOF'
terraform-yc-bootstrap image

Commands:
  bootstrap   Smart create-or-attach + plan/apply
  join        Attach-only (never creates cloud) + plan
  <terraform> Any terraform subcommand (plan, apply, output, ...)

Examples:
  # Prefer an empty work directory (not the git repo root):
  mkdir -p work
  docker run --rm --env-file .env -v "$PWD/work:/work" IMAGE bootstrap
  docker run --rm --env-file .env -v "$PWD/work:/work" IMAGE join
  docker run --rm --env-file .env -v "$PWD/work:/work" IMAGE plan
EOF
    exit 0
    ;;
esac

mkdir -p "$WORK_DIR"

# Seed writable work dir from baked module when empty (no versions.tf yet).
if [[ ! -f "${WORK_DIR}/versions.tf" && ! -f "${WORK_DIR}/backend.tf.in" ]]; then
  if command -v cp >/dev/null 2>&1; then
    cp -a "${MODULE_DIR}/." "${WORK_DIR}/"
  else
    tar -C "$MODULE_DIR" -cf - . | tar -C "$WORK_DIR" -xf -
  fi
fi

cd "$WORK_DIR" || exit

case "$cmd" in
  bootstrap)
    exec /bin/bash "${MODULE_DIR}/scripts/bootstrap.sh" "$@"
    ;;
  join)
    exec /bin/bash "${MODULE_DIR}/scripts/join.sh" "$@"
    ;;
  *)
    exec terraform "$cmd" "$@"
    ;;
esac
