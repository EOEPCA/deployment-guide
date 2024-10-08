# Load utility functions
source ../common/utils.sh

ask "GITLAB_APP_ID" "Enter the SharingHub Application ID" "" is_non_empty
ask "GITLAB_APP_SECRET" "Enter the SharingHub Secret" "" is_non_empty

echo "Successfully saved variables to state"
