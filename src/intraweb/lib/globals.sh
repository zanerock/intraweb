# set in the main CLI; declared here for completness
ACTION=""
ASSUME_DEFAULTS=""
PROJECT=""
ORGANIZATION=""
SITE_SETTINGS_FILE=""
# end cli option globals

VALID_ACTIONS="create build deploy run update-settings"
INTRAWEB_SITE_SETTINGS="INTRAWEB_SITE_ORGANIZATION \
INTRAWEB_SITE_PROJECT \
INTRAWEB_SITE_BUCKET \
INTRAWEB_SITE_REGION \
INTRAWEB_SITE_SUPPORT_EMAIL"

INTRAWEB_DB="${HOME}/.liq/intraweb"
INTRAWEB_SITES="${INTRAWEB_DB}/sites"
INTRAWEB_CACHE="${INTRAWEB_DB}/cache"
INTRAWEB_TMP_ERROR="${INTRAWEB_CACHE}/temp-error.txt"

# TODO: not currently used...
# INTRAWEB_DEFAULT_SETTINGS="${INTRAWEB_DB}/default-site-settings.sh"
