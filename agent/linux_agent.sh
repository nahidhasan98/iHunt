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

# Function to install required packages if missing
install_packages() {
    local packages=(wget jq)
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

# Check if wget and jq are installed
install_packages

# Run the following commands to download and install the agent:
echo "Downloading Wazuh agent..."
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.3-1_amd64.deb
echo "Downloaded Wazuh agent"

echo "Installing Wazuh agent..."
sudo WAZUH_MANAGER='43.240.100.76' WAZUH_AGENT_GROUP='default,Linux' WAZUH_AGENT_NAME="$WAZUH_AGENT_NAME" dpkg -i ./wazuh-agent_4.7.3-1_amd64.deb
echo "Installed Wazuh agent"

# Start the agent:
# We will start the agent after modifying the configuration

# STEP 2:
# Enabling the remote commands on agent:
LOCAL_INTERNAL_CONF_FILE="/var/ossec/etc/local_internal_options.conf"
echo 'logcollector.remote_commands=1' >>"$LOCAL_INTERNAL_CONF_FILE"
echo 'wazuh_command.remote_commands=1' >>$LOCAL_INTERNAL_CONF_FILE

# STEP 3:
# Creating file list ar (ar_file_list_linux.sh)
AR_FILE_LIST_LINUX="/var/ossec/active-response/bin/ar_file_list_linux.sh"
touch "$AR_FILE_LIST_LINUX"

cat <<'EOF' >$AR_FILE_LIST_LINUX
#!/bin/bash

# Get the current directory
directory="/var/ossec/active-response/bin/"

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
echo "[$current_time] AR_FILE_LIST_MAC: $file_list" >> "/var/ossec/active-response/custom_ar.log"

exit 0
EOF

sudo chmod 750 "$AR_FILE_LIST_LINUX"
sudo chown root:wazuh "$AR_FILE_LIST_LINUX"

# Creating log file for ar_file_list that will be captured by wazuh
CUSTOM_AR="/var/ossec/active-response/custom_ar.log"
touch "$CUSTOM_AR"
sudo chmod 750 "$CUSTOM_AR"
sudo chown root:wazuh "$CUSTOM_AR"

# STEP 4:
# Creating master ar
MASTER_AR_LINUX="/var/ossec/active-response/bin/master_ar_linux.sh"
touch "$MASTER_AR_LINUX"

cat <<'EOF' >$MASTER_AR_LINUX
#!/bin/bash

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

# Function to create file from JSON content
create_file_from_json() {
    local json_url="$1"

    # Check if curl and jq are installed
    install_packages

    # Fetch JSON content from the URL
    local json=$(curl -sSL "$json_url")

    # Extract filename and content from JSON using jq
    local filename=$(echo "$json" | jq -r '.file_name')
    local filecontent=$(echo "$json" | jq -r '.content')
    # Check if filename and content are retrieved successfully
    if [ -z "$filename" ] || [ -z "$filecontent" ]; then
        echo "Error: Unable to retrieve filename or content from JSON."
        exit 1
    fi

    # Create the file with the extracted filename and content
    filename="/var/ossec/active-response/bin/$filename"
    echo "$filecontent" >"$filename"

    # Check if file creation was successful
    if [ $? -eq 0 ]; then
        # Set file permissions and ownership
        sudo chmod 750 "$filename"
        sudo chown root:wazuh "$filename"

        if [ $? -ne 0 ]; then
            echo "Error: Failed to set permissions and ownership for file '$filename'."
            exit 1
        fi

        echo "File '$filename' created successfully."
    else
        echo "Error: Failed to create file '$filename'."
        exit 1
    fi
}

# Main script execution with argument check

read INPUT_JSON
JSON_URL=$(echo $INPUT_JSON | jq -r .parameters.extra_args[0])
if [ -z "$JSON_URL" ]; then
    echo "Error: Unable to retrieve args"
    exit 1
fi

# Call function to create file from JSON content
create_file_from_json "$JSON_URL"

exit 0
EOF

sudo chmod 750 "$MASTER_AR_LINUX"
sudo chown root:wazuh "$MASTER_AR_LINUX"

# Start the agent:
echo "Starting Wazuh agent..."
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
echo "Started Wazuh agent"

echo "Script run successfully."
