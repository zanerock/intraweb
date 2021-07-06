# set in the main CLI; declared here for completness
ACTION=""
ASSUME_DEFAULTS=""
PROJECT=""
ORGANIZATION=""
# end cli option globals

VALID_ACTIONS="init build deploy run"
INTRAWEB_SETTINGS="INTRAWEB_DEFAULT_ORGANIZATION INTRAWEB_PROJECT_PREFIX INTRAWEB_COMPANY_NAME INTRAWEB_OAUTH_SUPPORT_EMAIL"

INTRAWEB_DB="${HOME}/.liq/intraweb"
INTRAWEB_CACHE="${INTRAWEB_DB}/cache"
INTRAWEB_TMP_ERROR="${INTRAWEB_CACHE}/temp-error.txt"

INTRAWEB_SETTINGS_FILE="${INTRAWEB_DB}/settings.sh"
