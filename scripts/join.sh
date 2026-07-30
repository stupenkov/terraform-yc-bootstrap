#!/usr/bin/env bash
# Attach-only: discover workspace meta, write backend files, mint AWS keys, terraform init + plan.
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
# shellcheck source=lib/workspace.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/workspace.sh"

require_yc_auth
[[ -n "${YC_TOKEN:-}" ]] || die "join requires YC_TOKEN for API discovery (Bearer)"

log "Join: attach to existing bootstrap workspace (never creates cloud)"
attach_workspace require
tf_plan_only
log "Join complete. Day-two: docker run --rm --env-file .env -v \"\$PWD:/work\" <image> plan|apply"
log "  # or: docker compose run --rm tf plan|apply"
log "Optional: merge TF_VAR_cloud_id from terraform/.workspace.env into .env"
