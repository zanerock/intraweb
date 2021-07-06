intraweb-build() {
  # first, we do our own global auth check
  gcloud-lib-common-options-check-access-and-report
  # and now we can skip the auth check for the individual steps
  local COMMON_OPTS="--skip-auth-check"
  local PROJECT_CREATE_OPTS="${COMMON_OPTS} --organization ${ORGANIZATION}"
  local IAP_OPTS="${COMMON_OPTS}"
  local BUCKET_CREATE_OPTS="${COMMON_OPTS}"
  local APP_CREATE_OPTS="${COMMON_OPTS}"
  if [[ -n "${PROJECT:-}" ]]; then
    PROJECT_CREATE_OPTS="${PROJECT_CREATE_OPTS} --project ${PROJECT}"
    IAP_OPTS="${IAP_OPTS} --project ${PROJECT}"
    BUCKET_CREATE_OPTS="${BUCKET_CREATE_OPTS} --project ${PROJECT}"
    APP_CREATE_OPTS="${APP_CREATE_OPTS} --project ${PROJECT}"
  fi
  if [[ -n "${ASSUME_DEFAULTS:-}" ]]; then
    PROJECT_CREATE_OPTS="${PROJECT_CREATE_OPTS} --non-interactive --create-if-necessary"
    IAP_OPTS="${IAP_OPTS} --non-interactive"
    BUCKET_CREATE_OPTS="${BUCKET_CREATE_OPTS} --non-interactive --create-if-necessary"
    [[ -z "${BUCKET}" ]] || BUCKET_CREATE_OPTS="${BUCKET_CREATE_OPTS} --bucket ${BUCKET}"
    APP_CREATE_OPTS="${APP_CREATE_OPTS} --non-interactive --create-if-necessary"
  fi
  [[ -z "${APPLICATION_TITLE}" ]] || IAP_OPTS="${IAP_OPTS} --application-title '${APPLICATION_TITLE}'"
  [[ -z "${SUPPORT_EMAIL}" ]] || IAP_OPTS="${IAP_OPTS} --support-email '${SUPPORT_EMAIL}'"
  [[ -z "${REGION}" ]] || APP_CREATE_OPTS="${APP_CREATE_OPTS} --region ${REGION}" # TODO: do others take a region?

  # no 'eval' necessary here; we don't expect any spaces (see note below in 'gcloud-projects-iap-oauth-setup' call)
  gcloud-projects-create ${PROJECT_CREATE_OPTS}

  # without the eval, the '-quotes get read as literal, to the tokens end up being like:
  # --application_title|'Foo|Bar'|--support_email|'foo@bar.com'
  # as if the email literally began and ended with ticks and any title with spaces gets cut up.
  eval gcloud-projects-iap-oauth-setup ${IAP_OPTS}
  gcloud-app-create ${APP_CREATE_OPTS}
  gcloud-storage-buckets-create ${BUCKET_CREATE_OPTS}
  gcloud-storage-buckets-configure ${COMMON_OPTS} \
    --bucket ${BUCKET} \
    --make-uniform \
    --reader "serviceAccount:${PROJECT}@appspot.gserviceaccount.com"
}