#!/usr/bin/env bash
# Runs inside stupean/yandex-terraform (Compose service `bootstrap` overrides entrypoint).
# Orchestrates: local init/apply → migrate state to Yandex Object Storage.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BACKEND_TEMPLATE="${BACKEND_TEMPLATE:-backend.tf.in}"
BACKEND_TF="${BACKEND_TF:-backend.tf}"
BACKEND_HCL="${BACKEND_HCL:-backend.hcl}"
STATE_META=".terraform/terraform.tfstate"
LOCAL_STATE="terraform.tfstate"
MIGRATE_RETRIES="${MIGRATE_RETRIES:-5}"
MIGRATE_RETRY_SLEEP="${MIGRATE_RETRY_SLEEP:-5}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_yc_auth() {
  if [[ -z "${YC_TOKEN:-}" && -z "${YC_SERVICE_ACCOUNT_KEY_FILE:-}" ]]; then
    die "YC_TOKEN or YC_SERVICE_ACCOUNT_KEY_FILE must be set (copy .env.example → .env)"
  fi
}

backend_is_s3() {
  [[ -f "$STATE_META" ]] || return 1
  grep -q '"type": *"s3"' "$STATE_META" 2>/dev/null
}

# Prefer remote when meta says s3, or when partial backend files are already present.
prefer_remote() {
  backend_is_s3 && return 0
  [[ -f "$BACKEND_TF" && -f "$BACKEND_HCL" ]]
}

ensure_backend_tf() {
  if [[ ! -f "$BACKEND_TF" ]]; then
    [[ -f "$BACKEND_TEMPLATE" ]] || die "missing ${BACKEND_TEMPLATE}"
    cp "$BACKEND_TEMPLATE" "$BACKEND_TF"
    log "Installed ${BACKEND_TF} from ${BACKEND_TEMPLATE}"
  fi
}

remove_backend_tf_for_local() {
  # Local phase must not see an S3 backend block (terraform plan requires a configured backend).
  if [[ -f "$BACKEND_TF" ]]; then
    rm -f "$BACKEND_TF"
    log "Removed ${BACKEND_TF} for local-state phase"
  fi
}

write_backend_hcl() {
  local bucket="$1"
  local key="$2"
  cat >"$BACKEND_HCL" <<EOF
bucket = "${bucket}"
key    = "${key}"
EOF
  log "Wrote ${BACKEND_HCL} (gitignored)"
}

load_aws_creds_from_file() {
  local file="${BACKEND_CREDENTIALS_FILE:-.backend-credentials}"
  local line key val
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      AWS_ACCESS_KEY_ID) AWS_ACCESS_KEY_ID="$val" ;;
      AWS_SECRET_ACCESS_KEY) AWS_SECRET_ACCESS_KEY="$val" ;;
    esac
  done <"$file"
  [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]] || return 1
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
}

# Prefer env → .backend-credentials on disk → terraform output (local backend only).
# Never call terraform output after backend.tf is installed but before migrate init.
load_aws_creds() {
  if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    return 0
  fi
  if load_aws_creds_from_file; then
    log "Loaded AWS credentials from ${BACKEND_CREDENTIALS_FILE:-.backend-credentials}"
    return 0
  fi
  AWS_ACCESS_KEY_ID="$(terraform output -raw tfstate_access_key)"
  AWS_SECRET_ACCESS_KEY="$(terraform output -raw tfstate_secret_key)"
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
}

tf_plan_apply() {
  log "terraform plan"
  terraform plan -input=false -out=tfplan

  if [[ "${BOOTSTRAP_AUTO_APPROVE:-}" == "1" || "${BOOTSTRAP_AUTO_APPROVE:-}" == "true" ]]; then
    log "terraform apply (BOOTSTRAP_AUTO_APPROVE set)"
    terraform apply -input=false tfplan
  else
    log "Review the plan above. Set BOOTSTRAP_AUTO_APPROVE=1 in .env and re-run:"
    log "  docker compose run --rm bootstrap"
    rm -f tfplan
    die "refusing to apply without BOOTSTRAP_AUTO_APPROVE=1"
  fi
  rm -f tfplan
}

init_remote() {
  ensure_backend_tf
  [[ -f "$BACKEND_HCL" ]] || die "missing ${BACKEND_HCL} (bucket/key); recreate from bootstrap outputs or previous run"
  log "terraform init (remote S3, -backend-config=${BACKEND_HCL})"
  terraform init -input=false -backend-config="$BACKEND_HCL"
}

run_migrate_init() {
  local attempt=1
  log "Migrating local state → remote S3 (retries=${MIGRATE_RETRIES}, sleep=${MIGRATE_RETRY_SLEEP}s)"
  while true; do
    if terraform init -input=false -migrate-state -force-copy \
      -backend-config="$BACKEND_HCL"; then
      log "Remote backend active"
      return 0
    fi
    if (( attempt >= MIGRATE_RETRIES )); then
      die "migrate failed after ${MIGRATE_RETRIES} attempts; local state preserved for retry"
    fi
    log "Migrate attempt ${attempt}/${MIGRATE_RETRIES} failed; retrying in ${MIGRATE_RETRY_SLEEP}s (IAM propagation?)"
    sleep "$MIGRATE_RETRY_SLEEP"
    attempt=$((attempt + 1))
  done
}

migrate_to_remote() {
  local bucket key
  # Read outputs/creds while local backend still works — before installing backend.tf.
  bucket="$(terraform output -raw tfstate_bucket)"
  key="$(terraform output -raw bootstrap_state_key)"
  [[ -n "$bucket" ]] || die "tfstate_bucket output is empty"
  [[ -n "$key" ]] || die "bootstrap_state_key output is empty"
  load_aws_creds

  ensure_backend_tf
  write_backend_hcl "$bucket" "$key"
  run_migrate_init
}

local_state_has_bucket() {
  [[ -f "$LOCAL_STATE" ]] || return 1
  terraform output -raw tfstate_bucket >/dev/null 2>&1
}

# --- main -------------------------------------------------------------------

require_yc_auth

if prefer_remote; then
  log "Remote backend path (S3 meta and/or ${BACKEND_TF}+${BACKEND_HCL})"
  # Unfinished migrate: local state still present while backend files exist.
  if [[ -f "$LOCAL_STATE" ]] && ! backend_is_s3; then
    log "Local state present — finishing migrate before day-two"
    # .backend-credentials is written at apply but env_file is not reloaded mid-run —
    # read it from disk. Fall back to outputs only with local backend (-backend=false).
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

# Phase 1 / resume: local state only
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
