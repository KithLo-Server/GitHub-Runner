#!/usr/bin/env sh
set -eu

: "${ACCESS_TOKEN:?ACCESS_TOKEN is required}"
: "${RUNNER_SCOPE:?RUNNER_SCOPE is required (must be 'repo' or 'org')}"
: "${RUNNER_WORK_DIR:?RUNNER_WORK_DIR is required}"
: "${RUNNER_STATE_DIR:?RUNNER_STATE_DIR is required}"
: "${RUNNER_LABELS:?RUNNER_LABELS is required}"
RUNNER_GROUP=${RUNNER_GROUP:-Default}

case "${RUNNER_SCOPE}" in
  repo)
    : "${REPO_NAME:?REPO_NAME is required when RUNNER_SCOPE=repo}"
    AUTH_URL="https://api.github.com/repos/${REPO_NAME}/actions/runners/registration-token"
    RUNNER_URL="https://github.com/${REPO_NAME}"
    ;;
  org)
    : "${ORG_NAME:?ORG_NAME is required when RUNNER_SCOPE=org}"
    AUTH_URL="https://api.github.com/orgs/${ORG_NAME}/actions/runners/registration-token"
    RUNNER_URL="https://github.com/${ORG_NAME}"
    ;;
  *)
    echo "RUNNER_SCOPE must be either 'repo' or 'org', got '${RUNNER_SCOPE}'" >&2
    exit 1
    ;;
esac

if [ -n "${RUNNER_STACK_NAME:-}" ] || [ -n "${RUNNER_STACK_SIZE:-}" ]; then
  if [ -z "${RUNNER_STACK_NAME:-}" ]; then
    echo "RUNNER_STACK_NAME is required when RUNNER_STACK_SIZE is set" >&2
    exit 1
  fi
  if [ -z "${RUNNER_STACK_SIZE:-}" ]; then
    echo "RUNNER_STACK_SIZE is required when RUNNER_STACK_NAME is set" >&2
    exit 1
  fi

  case "${RUNNER_STACK_SIZE}" in
    ''|*[!0-9]*)
      echo "RUNNER_STACK_SIZE must be a positive integer, got '${RUNNER_STACK_SIZE}'" >&2
      exit 1
      ;;
  esac
  if [ "${RUNNER_STACK_SIZE}" -le 0 ]; then
    echo "RUNNER_STACK_SIZE must be a positive integer, got '${RUNNER_STACK_SIZE}'" >&2
    exit 1
  fi

  while :; do
    CONTAINERS="$(docker ps -q --filter "label=RUNNER_STACK_NAME=${RUNNER_STACK_NAME}")"
    COUNT="$(printf '%s\n' "${CONTAINERS}" | sed '/^$/d' | wc -l)"
    [ "${COUNT}" -eq "${RUNNER_STACK_SIZE}" ] && break
    echo "waiting for ${RUNNER_STACK_SIZE} stack containers, found ${COUNT}"
    sleep 5
  done

  CONTAINERS="$(printf '%s\n' "${CONTAINERS}" | sort)"

  printf '%s\n' "${CONTAINERS}" | grep -qx "${HOSTNAME}" || {
    echo "runner container ${HOSTNAME} not found in stack" >&2
    exit 1
  }

  INDEX="$(printf '%s\n' "${CONTAINERS}" | grep -nx "${HOSTNAME}" | cut -d: -f1)"

  RUNNER_NAME="${RUNNER_STACK_NAME}-${INDEX}"
  RUNNER_LABELS="${RUNNER_LABELS},${RUNNER_STACK_NAME},${RUNNER_NAME}"
  RUNNER_WORK_DIR="${RUNNER_WORK_DIR}/${RUNNER_NAME}"
  RUNNER_STATE_DIR="${RUNNER_STATE_DIR}/${RUNNER_NAME}"
  unset RUNNER_STACK_NAME
  unset RUNNER_STACK_SIZE
else
  : "${RUNNER_NAME:?RUNNER_NAME is required}"
fi

echo "Name: $RUNNER_NAME"

mkdir -p "${RUNNER_WORK_DIR}"
mkdir -p "${RUNNER_STATE_DIR}"

PATCH_FILE="${RUNNER_STATE_DIR}/runner-config.patch"
PERMS_FILE="${RUNNER_STATE_DIR}/runner-perms.sh"

fetch_token() {
  curl -fsSL \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    "${AUTH_URL}" \
    | jq -r '.token'
}

configure_runner() {
  echo "Configuring"

  ./config.sh \
    --url "${RUNNER_URL}" \
    --token "$(fetch_token)" \
    --name "${RUNNER_NAME}" \
    --work "${RUNNER_WORK_DIR}" \
    --labels "${RUNNER_LABELS}" \
    --runnergroup "${RUNNER_GROUP}" \
    --unattended \
    --replace

  git add -A
  git diff --cached --binary > "${PATCH_FILE}"

  git diff --cached --name-only | while IFS= read -r file; do
    if [ -e "${file}" ]; then
      stat -c 'chown %U:%G "%n" && chmod %a "%n"' "${file}"
    fi
  done > "${PERMS_FILE}"

  chmod 600 "${PATCH_FILE}" "${PERMS_FILE}"
}

run_runner() {
  unset ACCESS_TOKEN
  unset RUNNER_NAME
  unset RUNNER_SCOPE
  unset RUNNER_WORK_DIR
  unset RUNNER_STATE_DIR
  unset RUNNER_GROUP
  unset REPO_NAME
  unset ORG_NAME
  unset RUNNER_LABELS

  ./run.sh
}

if [ -f "${PATCH_FILE}" ]; then
  echo "Restoring runner configuration from patch"

  git apply --whitespace=nowarn --binary "${PATCH_FILE}"
  sh "${PERMS_FILE}"
else
  configure_runner
fi

set +e
(run_runner)
set -e

echo "runner exited, reconfiguring and retrying"

./config.sh remove --token "$(fetch_token)" || echo "warning: config.sh remove failed"

git reset --hard -q HEAD
git clean -fdxq

configure_runner

run_runner
