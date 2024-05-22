#!/bin/bash

# Cheching sudo permission
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo privileges."
    exit 1
fi

###############################################################################################
### Installing Clamav antivirus on linux                                                    ###
### Ref: https://docs.clamav.net/                                                           ###
### Ref: oms.brotecs.com/issues/73977                                                       ###
###############################################################################################

# STEP 1: Create clamav user and group
echo "Creating clamav user & group..."
groupadd clamav
useradd -g clamav -s /bin/false -c "Clam Antivirus" clamav
echo "Created clamav user & group."

# STEP 2: Create the required directories
echo "Creating required directories..."

# Define directories
configDir="/etc/clamav"
databaseDir="/var/lib/clamav"
logDir="/var/log/clamav"
freshclamLogFile="$logDir/freshclam.log"
clamavLogFile="$logDir/clamav.log"
clamOnAccLogFile="$logDir/clamonacc.log"

# Check if directories exist, if not, create them
[ ! -d "$configDir" ] && sudo mkdir -p "$configDir"
[ ! -d "$databaseDir" ] && sudo mkdir -p "$databaseDir"
[ ! -d "$logDir" ] && sudo mkdir -p "$logDir"

# Create the freshclam.log file if it does not exist
[ ! -f "$freshclamLogFile" ] && sudo touch "$freshclamLogFile"
[ ! -f "$clamOnAccLogFile" ] && sudo touch "$clamOnAccLogFile"
# clamav.log will be created by clamav automatically

# Set owner for database directory
sudo chown clamav:clamav -R "$databaseDir"
if [ $? -ne 0 ]; then
    echo "Failed to change ownership of $databaseDir"
    exit 1
fi
echo "Created required directories."

# STEP 3: Install clamav and clamav-daemon
echo "Installing clamav..."

# Function to check if a package is installed
is_package_installed() {
    dpkg -s "$1" &>/dev/null
}

# List of packages to install
packages=("clamav" "clamav-daemon")

# Check if each package is installed
for package in "${packages[@]}"; do
    if is_package_installed "$package"; then
        echo "$package is already installed."
    else
        echo "Installing $package..."
        sudo apt-get install -y "$package"
        if [ $? -eq 0 ]; then
            echo "$package has been successfully installed."
        else
            echo "Failed to install $package. Please check your internet connection or try again later."
            exit 1
        fi
    fi
done
echo "Installed clamav."

# STEP 4: Some settings for on-access notification
echo "Setting up inotify watch-points..."

# On-Access scanning FANOTIFY setup
echo 524288 | sudo tee -a /proc/sys/fs/inotify/max_user_watches

# STEP 5: Modifications of clamav configuration files
echo "Modifying clamav configuration files..."

# copying conf file to keep backup
sudo cp -p /etc/clamav/clamd.conf /etc/clamav/clamd.conf.backup
sudo cp -p /etc/clamav/freshclam.conf /etc/clamav/freshclam.conf.backup

# Function to modify configuration file
modify_config() {
    local config_file="$1"
    local -n modifications=$2

    # Use a temporary file to store the changes
    local temp_file=$(mktemp)

    # Process the file line by line
    while IFS= read -r line; do
        local modified=false
        for key in "${!modifications[@]}"; do
            if [[ "$line" == "$key"* ]]; then
                echo "${modifications[$key]}" >>"$temp_file"
                modified=true
                break
            fi
        done
        if [ "$modified" = false ]; then
            echo "$line" >>"$temp_file"
        fi
    done <"$config_file"

    # Check if any required lines were missing and add them
    for key in "${!modifications[@]}"; do
        if ! grep -q "${modifications[$key]}" "$temp_file"; then
            echo "${modifications[$key]}" >>"$temp_file"
        fi
    done

    # Move the temporary file to the original file path
    sudo mv -f "$temp_file" "$config_file"
    sudo chmod "${permissions[$config_file]}" "$config_file"
    sudo chown "${ownership[$config_file]}" "$config_file"
}

# Define the file paths and their permissions and ownerships
declare -A configs=(
    ["/etc/clamav/freshclam.conf"]="/etc/clamav/freshclam.conf"
    ["/etc/clamav/clamd.conf"]="/etc/clamav/clamd.conf"
)

declare -A permissions=(
    ["/etc/clamav/freshclam.conf"]=$(stat -c "%a" /etc/clamav/freshclam.conf)
    ["/etc/clamav/clamd.conf"]=$(stat -c "%a" /etc/clamav/clamd.conf)
)

declare -A ownership=(
    ["/etc/clamav/freshclam.conf"]=$(stat -c "%u" /etc/clamav/freshclam.conf):$(stat -c "%g" /etc/clamav/freshclam.conf)
    ["/etc/clamav/clamd.conf"]=$(stat -c "%u" /etc/clamav/clamd.conf):$(stat -c "%g" /etc/clamav/clamd.conf)
)

# Modifications for each configuration file
declare -A freshclam_modifications=(
    ["TestDatabases"]="TestDatabases no"
)

# Get the current username
current_user=${SUDO_USER:-$(whoami)}

declare -A clamd_modifications=(
    ["MaxThreads"]="MaxThreads 20"
    ["OnAccessIncludePath /home/$current_user/Downloads"]="OnAccessIncludePath /home/$current_user/Downloads"
    ["OnAccessIncludePath /root"]="OnAccessIncludePath /root"
    ["OnAccessPrevention"]="OnAccessPrevention yes"
    ["OnAccessExtraScanning"]="OnAccessExtraScanning yes"
    ["OnAccessExcludeUname"]="OnAccessExcludeUname clamav"
)

# Loop through configuration files and apply modifications
for config_path in "${!configs[@]}"; do
    case "$config_path" in
    "/etc/clamav/freshclam.conf")
        modify_config "$config_path" freshclam_modifications
        ;;
    "/etc/clamav/clamd.conf")
        modify_config "$config_path" clamd_modifications
        ;;
    *)
        echo "Unknown configuration file: $config_path"
        ;;
    esac
done

echo "Modified clamav configuration files."

# STEP 6: Create clamonacc service for realtime scanning and start the service
echo "Creating clamonacc service..."

# Define the content of the systemd service file
CLAMONACC_SERVICE_FILE="/etc/systemd/system/clamonacc.service"

# Check if the service file already exists
if [ -f "$CLAMONACC_SERVICE_FILE" ]; then
    echo "clamonacc.service already exists."
else
    # Define the content of the systemd service file
    CLAMONACC_SERVICE_CONTENT="[Unit]
Description=Clamonacc - realtime scanning
Requires=clamav-daemon.service
After=clamav-daemon.service syslog.target network.target

[Service]
Type=simple
User=root
ExecStart=/usr/sbin/clamonacc --foreground --log=/var/log/clamav/clamonacc.log
Restart=on-failure
RestartSec=120s

[Install]
WantedBy=multi-user.target
"
    # Write the content to the cl.service file
    echo "$CLAMONACC_SERVICE_CONTENT" | sudo tee "$CLAMONACC_SERVICE_FILE" >/dev/null

    # Reload systemd daemon to apply changes
    sudo systemctl daemon-reload

    echo "clamonacc.service created successfully."
fi

# Start clamonacc service
sudo systemctl enable clamonacc.service
sudo systemctl start clamonacc.service

echo "Created and satrted clamonacc service."

# STEP 7: Changing permission for log file access
echo "Changing log files permission..."

sudo chmod 664 "$freshclamLogFile" "$clamavLogFile" "$clamOnAccLogFile"
if [ $? -ne 0 ]; then
    echo "Failed to change permissions of log files"
    exit 1
fi

sudo chown clamav:clamav "$clamOnAccLogFile"
if [ $? -ne 0 ]; then
    echo "Failed to change ownership of $clamOnAccLogFile"
    exit 1
fi

echo "Changed log files permission."

echo "Script run successfully."
