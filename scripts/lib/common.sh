#!/usr/bin/env bash
# Shared bootstrap/join helpers (sourced, not executed).
# shellcheck shell=bash

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPTS_DIR}/.." && pwd)"

# Terraform root:
# - checkout: <repo>/terraform (sibling of scripts/)
# - image:    /module with scripts at /module/scripts (parent of scripts/ is the module)
# Entrypoint may export MODULE_DIR / WORK_DIR explicitly.
if [[ -z "${MODULE_DIR:-}" ]]; then
  if [[ -d "${REPO_ROOT}/terraform" ]]; then
    MODULE_DIR="${REPO_ROOT}/terraform"
  elif [[ -f "${REPO_ROOT}/backend.tf.in" || -f "${REPO_ROOT}/versions.tf" ]]; then
    MODULE_DIR="${REPO_ROOT}"
  else
    MODULE_DIR="${REPO_ROOT}/terraform"
  fi
fi
# Writable workspace: same as module for Compose; /work for docker run (set by entrypoint).
WORK_DIR="${WORK_DIR:-${MODULE_DIR}}"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

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

prefer_remote() {
  backend_is_s3 && return 0
  [[ -f "$BACKEND_TF" && -f "$BACKEND_HCL" ]]
}

ensure_backend_tf() {
  if [[ ! -f "$BACKEND_TF" ]]; then
    if [[ -f "$BACKEND_TEMPLATE" ]]; then
      cp "$BACKEND_TEMPLATE" "$BACKEND_TF"
    elif [[ -f "${MODULE_DIR}/${BACKEND_TEMPLATE}" ]]; then
      cp "${MODULE_DIR}/${BACKEND_TEMPLATE}" "$BACKEND_TF"
    else
      die "missing ${BACKEND_TEMPLATE} (looked in ${WORK_DIR} and ${MODULE_DIR})"
    fi
    log "Installed ${BACKEND_TF} from ${BACKEND_TEMPLATE}"
  fi
}

remove_backend_tf_for_local() {
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
    log "  docker run --rm --env-file .env <image> bootstrap"
    log "  # or: docker compose run --rm bootstrap"
    rm -f tfplan
    die "refusing to apply without BOOTSTRAP_AUTO_APPROVE=1"
  fi
  rm -f tfplan
}

tf_plan_only() {
  log "terraform plan (no apply)"
  terraform plan -input=false
}

init_remote() {
  ensure_backend_tf
  [[ -f "$BACKEND_HCL" ]] || die "missing ${BACKEND_HCL}"
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
  bucket="$(terraform output -raw tfstate_bucket)"
  key="$(terraform output -raw bootstrap_state_key)"
  [[ -n "$bucket" ]] || die "tfstate_bucket output is empty"
  [[ -n "$key" ]] || die "bootstrap_state_key output is empty"
  load_aws_creds

  ensure_backend_tf
  write_backend_hcl "$bucket" "$key"
  run_migrate_init
  log "Workspace meta is managed by Terraform (yandex_storage_object.workspace_meta → ${WORKSPACE_META_KEY:-bootstrap/workspace.json})"
}

local_state_has_bucket() {
  [[ -f "$LOCAL_STATE" ]] || return 1
  terraform output -raw tfstate_bucket >/dev/null 2>&1
}
