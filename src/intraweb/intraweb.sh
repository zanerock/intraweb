#!/usr/bin/env bash

import strict

import echoerr
import options
import prompt
import real_path

source ./inc.sh

# The first group are user visible config options. These will be automatically provided if '--assume-defaults' is
# toggled.
#
# The second group, staarting at '--assume-defaults', affect the behavior of the app.
#
# The third group, starting at '--organization', affect associotions of any created components. These can typically
# be gleaned from the active 'gcloud config', but can be overriden here.
eval "$(setSimpleOptions --script \
  SITE= \
  APPLICATION_TITLE:t= \
  SUPPORT_EMAIL:e= \
  ASSUME_DEFAULTS: \
  NO_DEPLOY_APP:A \
  NO_DEPLOY_CONTENT:C \
  ORGANIZATION= \
  PROJECT= \
  NO_INFER_PROJECT: \
  BUCKET= \
  REGION= \
  NO_INFER_REGION: -- "$@")"
ACTION="${1:-}"
if [[ -z "${ACTION}" ]]; then
  usage-bad-action # will exit process
fi

[[ -z "${SITE}" ]] || INTRAWEB_SITE_SETTINGS="${INTRAWEB_SITES}/${SITE}/settings.sh"
if [[ -n "${SITE}" ]] && [[ -f "${INTRAWEB_SITE_SETTINGS}" ]]; then
  source "${INTRAWEB_SITE_SETTINGS}"
fi

intraweb-helper-verify-settings() {
  local SETTING PROBLEMS

  for SETTING in $INTRAWEB_SETTINGS; do
    if [[ -z "${!SETTING:-}" ]]; then
      echoerr "Did not find expected setting: '${SETTING}'."
      PROBLEMS=true
    fi
    if [[ "${PROBLEMS}" == true ]]; then
      echoerrandexit "At least one parameter is not set. Try:\n\nintraweb init"
    fi
  done
}

[[ "${ACTION}" == init ]] || intraweb-helper-verify-settings "${SITE}"

# Process/set the association parameters.
[[ -n "${ORGANIZATION:-}" ]] || ORGANIZATION="${INTRAWEB_DEFAULT_ORGANIZATION}"

intraweb-helper-infer-associations() {
  local SETTING NO_SETTING GCLOUD_PROPERTY
  for SETTING in PROJECT REGION; do
    NO_SETTING="NO_INFER_${SETTING}"
    GCLOUD_PROPERTY="$(echo "${SETTING}" | tr '[:upper:]' '[:lower:]')"
    case "${GCLOUD_PROPERTY}" in
      region)
        GCLOUD_PROPERTY="compute/${GCLOUD_PROPERTY}" ;;
    esac

    if [[ -z "${!SETTING:-}" ]] && [[ -z "${!NO_SETTING:-}" ]]; then
      eval "${SETTING}=\$(gcloud config get-value ${GCLOUD_PROPERTY})"
      # Note the setting may remain undefined, and that's OK
      [[ -z "${!SETTING:-}" ]] || echofmt "Inferred ${SETTING} '${!SETTING}' from active gcloud conf."
    fi
  done
}
intraweb-helper-infer-associations

if [[ -n "${ASSUME_DEFAULTS}" ]]; then
  # is this a new project?
  [[ -n "${PROJECT:-}" ]] || PROJECT="${INTRAWEB_PROJECT_PREFIX}-intraweb"

  [[ -n "${BUCKET}" ]] || BUCKET="${PROJECT}"

  [[ -n "${APPLICATION_TITLE}" ]] || [[ -z "${INTRAWEB_COMPANY_NAME}" ]] \
    || APPLICATION_TITLE="${INTRAWEB_COMPANY_NAME} Intraweb"

  [[ -n "${SUPPORT_EMAIL}" ]] || [[ -z "${INTRAWEB_OAUTH_SUPPORT_EMAIL}" ]] || SUPPORT_EMAIL="${INTRAWEB_OAUTH_SUPPORT_EMAIL}"

  echofmt "Running with default values..."
fi

case "${ACTION}" in
  init|build|deploy|run)
    intraweb-${ACTION} ;;
  *)
    usage-bad-action ;;# will exit process
esac