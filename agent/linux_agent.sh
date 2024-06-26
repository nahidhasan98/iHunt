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

# Function to install required packages if missing
install_packages() {
    local packages=(curl jq)
    local missing_packages=()

    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -eq 0 ]; then
        echo "Required packages are already installed."
    else
        echo "Installing missing packages: ${missing_packages[*]}"
        if command -v apt &>/dev/null; then
            sudo apt update
            sudo apt install -y "${missing_packages[@]}"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "${missing_packages[@]}"
        else
            echo "Error: Package manager not found. Unable to install missing packages."
            exit 1
        fi
    fi
}

# Check if curl and jq are installed
install_packages

# Run the following commands to download and install the agent:
echo "Downloading iCyberHunt agent..."
curl -o wazuh-agent_4.7.3-1_amd64.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.3-1_amd64.deb
echo "Downloaded iCyberHunt agent"

echo "Installing iCyberHunt agent..."
sudo WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_AGENT_GROUP='default,LinuxOS' WAZUH_AGENT_NAME="$WAZUH_AGENT_NAME" dpkg -i ./wazuh-agent_4.7.3-1_amd64.deb
echo "Installed iCyberHunt agent"

# sleep the script for 7 seconds
sleep 7

# Remove the downloaded deb file after installation
sudo rm -f ./wazuh-agent_4.7.3-1_amd64.deb

# STEP 2:
# Modifying Wazuh agent keyword to iCyberHunt agent
ossec_file="/var/ossec/etc/ossec.conf"

sed -i \
    -e 's/^[[:space:]]*Wazuh - Agent - Default configuration/  iCyberHunt - Agent - Default configuration/' \
    -e '/^[[:space:]]*More info/d' \
    -e '/^[[:space:]]*Mailing list/d' \
    "$ossec_file"

# Start the agent:
# We will start the agent after modifying the configuration

# STEP 3:
# Enabling the remote commands on agent:
LOCAL_INTERNAL_CONF_FILE="/var/ossec/etc/local_internal_options.conf"
echo 'logcollector.remote_commands=1' >>"$LOCAL_INTERNAL_CONF_FILE"
echo 'wazuh_command.remote_commands=1' >>$LOCAL_INTERNAL_CONF_FILE

# STEP 4:
# Creating log file for custom ar (that will be captured by wazuh)
CUSTOM_AR="/var/ossec/active-response/custom_ar.log"
touch "$CUSTOM_AR"
sudo chmod 750 "$CUSTOM_AR"
sudo chown root:wazuh "$CUSTOM_AR"

echo "Downloading necesasry ar files..."
# STEP 5:
# Getting file_list ar
AR_FILE_LIST_LINUX="/var/ossec/active-response/bin/ar_file_list_linux"
curl -o $AR_FILE_LIST_LINUX https://raw.githubusercontent.com/nahidhasan98/iHunt/main/bin/wazuh/linux/ar_file_list_linux

sudo chmod 750 "$AR_FILE_LIST_LINUX"
sudo chown root:wazuh "$AR_FILE_LIST_LINUX"

# STEP 6:
# Getting master ar
MASTER_AR_LINUX="/var/ossec/active-response/bin/master_ar_linux"
curl -o $MASTER_AR_LINUX https://raw.githubusercontent.com/nahidhasan98/iHunt/main/bin/wazuh/linux/master_ar_linux

sudo chmod 750 "$MASTER_AR_LINUX"
sudo chown root:wazuh "$MASTER_AR_LINUX"

# STEP 7:
# Getting file_delete ar
AR_FILE_DELETE_LINUX="/var/ossec/active-response/bin/ar_file_delete_linux"
curl -o $AR_FILE_DELETE_LINUX https://raw.githubusercontent.com/nahidhasan98/iHunt/main/bin/wazuh/linux/ar_file_delete_linux

sudo chmod 750 "$AR_FILE_DELETE_LINUX"
sudo chown root:wazuh "$AR_FILE_DELETE_LINUX"

echo "Download done."

# Start the agent:
echo "Starting iCyberHunt agent..."
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
echo "Started iCyberHunt agent"

echo "Script run successfully."
