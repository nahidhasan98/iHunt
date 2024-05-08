#!/bin/bash

# Checking sudo permission
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo privileges."
    exit 1
fi

# STEP 1:
# Check if WAZUH_AGENT_NAME argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <WAZUH_AGENT_NAME>"
    exit 1
fi

# Assign the argument to WAZUH_AGENT_NAME variable
WAZUH_AGENT_NAME="$1"

# Check the machine hardware type
machine_type=$(uname -m)

if [ "$machine_type" == "arm64" ]; then
    # Apple Silicon (ARM) processor
    WAZUH_PKG_URL="https://packages.wazuh.com/4.x/macos/wazuh-agent-4.7.3-1.arm64.pkg"
else
    # Intel processor
    WAZUH_PKG_URL="https://packages.wazuh.com/4.x/macos/wazuh-agent-4.7.3-1.intel64.pkg"
fi

# Run the following commands to download and install the agent:
echo "Downloading Wazuh agent..."
curl -so wazuh-agent.pkg $WAZUH_PKG_URL
echo "Downloaded Wazuh agent"

echo "Installing Wazuh agent..."
echo "WAZUH_MANAGER='43.240.100.76' && WAZUH_AGENT_GROUP='default,macOS' && WAZUH_AGENT_NAME=\"$WAZUH_AGENT_NAME\"" >/tmp/wazuh_envs && sudo installer -pkg ./wazuh-agent.pkg -target /
echo "Installed Wazuh agent"

# Start the agent:
# We will start the agent after modifying the configuration

# STEP 2:
# Enabling the remote commands on agent:
LOCAL_INTERNAL_CONF_FILE="/Library/Ossec/etc/local_internal_options.conf"
echo 'logcollector.remote_commands=1' >>"$LOCAL_INTERNAL_CONF_FILE"
echo 'wazuh_command.remote_commands=1' >>$LOCAL_INTERNAL_CONF_FILE

# STEP 3:
# Creating file list ar (ar_file_list_mac.sh)
AR_FILE_LIST_MAC="/Library/Ossec/active-response/bin/ar_file_list_mac.sh"
touch "$AR_FILE_LIST_MAC"

cat <<'EOF' >$AR_FILE_LIST_MAC
#!/bin/bash

# Get the current directory
directory="/Library/Ossec/active-response/bin/"

# Declare an empty array to store filenames
file_array=()

# Collect filenames into the array
for file in "$directory"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        file_array+=("$filename")
    fi
done

# Create a comma-separated list of filenames
file_list=$(
    IFS=','
    echo "${file_array[*]}"
)

# Log the concatenated list of filenames to syslog
current_time=$(date +'%Y-%m-%d %H:%M:%S')
echo "[$current_time] AR_FILE_LIST_MAC: $file_list" >> "/Library/Ossec/active-response/custom_ar.log"

exit 0
EOF

sudo chmod 750 "$AR_FILE_LIST_MAC"
sudo chown root:wazuh "$AR_FILE_LIST_MAC"

# Creating log file for ar_file_list that will be captured by wazuh
CUSTOM_AR="/Library/Ossec/active-response/custom_ar.log"
touch "$CUSTOM_AR"
sudo chmod 750 "$CUSTOM_AR"
sudo chown root:wazuh "$CUSTOM_AR"

# STEP 4:
# todo: Creating master ar

# Start the agent:
echo "Starting Wazuh agent..."
sudo /Library/Ossec/bin/wazuh-control start
echo "Started Wazuh agent"

echo "Script run successfully."
