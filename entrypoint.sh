#!/usr/bin/env sh
set -eu

: "${ACCESS_TOKEN:?ACCESS_TOKEN is required}"
: "${RUNNER_NAME:?RUNNER_NAME is required}"
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

mkdir -p "${RUNNER_WORK_DIR}"
mkdir -p "${RUNNER_STATE_DIR}"
cp -p -r "${RUNNER_STATE_DIR}/." "/actions-runner"

if [ -f "/actions-runner/.runner" ]; then
  echo "The runner has already been configured"
else
  echo "Configuring"

  RUNNER_TOKEN=$(curl -fsSL \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    "${AUTH_URL}" \
    | jq -r '.token')

  RUNNER_ALLOW_RUNASROOT=1 ./config.sh \
    --url "${RUNNER_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --work "${RUNNER_WORK_DIR}" \
    --labels "${RUNNER_LABELS}" \
    --runnergroup "${RUNNER_GROUP}" \
    --unattended \
    --replace

  cp -p -r "/actions-runner/_diag" "/actions-runner/svc.sh" /actions-runner/.[^.]* "${RUNNER_STATE_DIR}"
fi

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
