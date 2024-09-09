source ~/.eoepca/state

# Function for checking if a command exists (validation)
command_exists() {
    command -v "$@" >/dev/null 2>&1
}

# Function for asking for variable
ask() {
    local variable=$1
    local message=$2
    local default_value=$3

    create_state_file

    if [ -n "${!variable}" ]; then
        echo "$variable is already set to '${!variable}', do you want to update it?"
        read -p "y/n: " update
        if [ "$update" != "y" ]; then
            return
        fi
    fi

    # Ask for input
    echo "$message"
    [ -n "$default_value" ] && echo "Default [$default_value]:"
    read -p "> " input
    input="${input:-$default_value}"

    export "$variable=$input"

    # Check if the variable already exists in the state file, as we need to overwrite.
    if grep -q "export $variable=" "$HOME/.eoepca/state"; then
        sed -i "s|export $variable=.*|export $variable=\"$input\"|" "$HOME/.eoepca/state"
    else
        echo "export $variable=\"$input\"" >>"$HOME/.eoepca/state"
    fi
}

# Function to create a state file
create_state_file() {
    STATE_FILE="$HOME/.eoepca/state"

    if [ -f "$STATE_FILE" ]; then
        return
    fi
    mkdir -p "$(dirname "$STATE_FILE")"
    touch "$STATE_FILE"
}

# Function to check if a resource exists
check_resource() {
    resource_type=$1
    resource_name=$2
    namespace=$3
    kubectl get $resource_type $resource_name -n $namespace &>/dev/null

    if [ $? -ne 0 ]; then
        echo "❌ $resource_type $resource_name not found in namespace $namespace."
    else
        echo "✅ $resource_type $resource_name found in namespace $namespace."
    fi
}

# Function to check if pods with specific name pattern are running
# TODO: There is no 'app' or nice label that combines the resources for the RC, so right now this is just checking via prefix.
#       Maybe we will need a seperate function, one for `check_pods_by_prefix` and one for `check_pods_by_label`
check_pods() {
    local prefix=$1
    echo "Checking if all pods starting with '$prefix' are in 'Running' state..."
    PODS=$(kubectl get pods -n $RESOURCE_CATALOGUE_NAMESPACE --no-headers | grep "^$prefix")

    if [ -z "$PODS" ]; then
        echo "❌ No pods found that start with '$prefix' in namespace '$RESOURCE_CATALOGUE_NAMESPACE'."
    fi

    # Internal field seperator set to empty to stop whitespace being trimmed
    while IFS= read -r pod; do
        POD_NAME=$(echo $pod | awk '{print $1}')
        POD_STATUS=$(echo $pod | awk '{print $3}')

        if [ "$POD_STATUS" != "Running" ]; then
            echo "❌ Pod $POD_NAME is not running (status: $POD_STATUS)."
            exit 1
        else
            echo "✅ Pod $POD_NAME is running."
        fi
    done <<<"$PODS"
}
