#!/bin/bash

# Checking sudo permission
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo privileges."
    exit 1
fi

# STEP 1:
# Check if WAZUH_AGENT_NAME argument is provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <iCyberHunt_AGENT_NAME> <environment:prod/dev>"
    exit 1
fi

# Assign the argument to variables
WAZUH_AGENT_NAME="$1"
ENVIRONMENT="$2"

if [ "$ENVIRONMENT" == "dev" ]; then
    WAZUH_MANAGER="43.240.100.76"
elif [ "$ENVIRONMENT" == "prod" ]; then
    WAZUH_MANAGER="202.191.121.110"
else
    echo "Unknown environment: $ENVIRONMENT"
    exit 1
fi

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
echo "Downloading iCyberHunt agent..."
curl -so wazuh-agent.pkg $WAZUH_PKG_URL
echo "Downloaded iCyberHunt agent"

echo "Installing iCyberHunt agent..."
echo "WAZUH_MANAGER=\"$WAZUH_MANAGER\" && WAZUH_AGENT_GROUP='default,macOS' && WAZUH_AGENT_NAME=\"$WAZUH_AGENT_NAME\"" >/tmp/wazuh_envs && sudo installer -pkg ./wazuh-agent.pkg -target /
echo "Installed iCyberHunt agent"

# sleep the script for 3 seconds
sleep 3

# Remove the downloaded MSI file after installation
sudo rm -f ./wazuh-agent.pkg

# STEP 2:
# Modifying Wazuh agent keyword to iCyberHunt agent
ossec_file="/Library/Ossec/etc/ossec.conf"

sed -i \
    -e 's/^[[:space:]]*Wazuh - Agent - Default configuration/  iCyberHunt - Agent - Default configuration/' \
    -e '/^[[:space:]]*More info/d' \
    -e '/^[[:space:]]*Mailing list/d' \
    "$ossec_file"

# Start the agent:
# We will start the agent after modifying the configuration

# STEP 3:
# Enabling the remote commands on agent:
LOCAL_INTERNAL_CONF_FILE="/Library/Ossec/etc/local_internal_options.conf"
echo 'logcollector.remote_commands=1' >>"$LOCAL_INTERNAL_CONF_FILE"
echo 'wazuh_command.remote_commands=1' >>$LOCAL_INTERNAL_CONF_FILE

# STEP 4:
# Creating log file for custom ar (that will be captured by wazuh)
CUSTOM_AR="/Library/Ossec/active-response/custom_ar.log"
touch "$CUSTOM_AR"
sudo chmod 750 "$CUSTOM_AR"
sudo chown root:wazuh "$CUSTOM_AR"

# STEP 5:
# Getting file_list ar
AR_FILE_LIST_MAC="/Library/Ossec/active-response/bin/ar_file_list_mac"
curl -so $AR_FILE_LIST_MAC https://raw.githubusercontent.com/nahidhasan98/iHunt/main/bin/wazuh/macos/ar_file_list_mac

sudo chmod 750 "$AR_FILE_LIST_MAC"
sudo chown root:wazuh "$AR_FILE_LIST_MAC"

# STEP 6:
# Getting master ar
MASTER_AR_MAC="/Library/Ossec/active-response/bin/master_ar_mac"
curl -so $MASTER_AR_MAC https://raw.githubusercontent.com/nahidhasan98/iHunt/main/bin/wazuh/macos/master_ar_mac

sudo chmod 750 "$MASTER_AR_MAC"
sudo chown root:wazuh "$MASTER_AR_MAC"

# STEP 7:
# Getting file_delete ar
AR_FILE_DELETE_MAC="/Library/Ossec/active-response/bin/ar_file_delete_mac"
curl -so $AR_FILE_DELETE_MAC https://raw.githubusercontent.com/nahidhasan98/iHunt/main/bin/wazuh/macos/ar_file_delete_mac

sudo chmod 750 "$AR_FILE_DELETE_MAC"
sudo chown root:wazuh "$AR_FILE_DELETE_MAC"

# Start the agent:
echo "Starting iCyberHunt agent..."
sudo /Library/Ossec/bin/wazuh-control start
echo "Started iCyberHunt agent"

echo "Script run successfully."
