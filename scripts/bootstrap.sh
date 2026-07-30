#!/usr/bin/env bash
# Smart bootstrap: attach if workspace exists, else create + migrate.
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
# shellcheck source=lib/workspace.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/workspace.sh"

require_yc_auth

if prefer_remote; then
  log "Remote backend path (S3 meta and/or ${BACKEND_TF}+${BACKEND_HCL})"
  if [[ -f "$LOCAL_STATE" ]] && ! backend_is_s3; then
    log "Local state present — finishing migrate before day-two"
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
      if ! load_aws_creds_from_file; then
        terraform init -input=false -backend=false
        load_aws_creds
      else
        log "Loaded AWS credentials from ${BACKEND_CREDENTIALS_FILE:-.backend-credentials}"
      fi
    fi
    ensure_backend_tf
    [[ -f "$BACKEND_HCL" ]] || die "missing ${BACKEND_HCL}"
    run_migrate_init
  fi
  init_remote
  tf_plan_apply
  exit 0
fi

# Smart attach: no local remote config yet — try discovery before create.
if [[ -n "${YC_TOKEN:-}" ]]; then
  log "Smart bootstrap: probing for existing workspace meta…"
  if attach_workspace attach; then
    log "Attached to existing workspace — day-two plan/apply"
    tf_plan_apply
    exit 0
  fi
  log "No existing workspace discovered — continuing with create path"
else
  log "YC_TOKEN unset — skip discovery (SA key file alone); create/resume local path"
fi

remove_backend_tf_for_local
log "Phase 1: terraform init (local state)"
terraform init -input=false

if local_state_has_bucket; then
  log "Local state already has tfstate_bucket — resume: plan/apply before migrate"
  tf_plan_apply
  migrate_to_remote
  exit 0
fi

tf_plan_apply
migrate_to_remote
