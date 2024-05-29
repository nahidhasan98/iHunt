#!/bin/bash

# Cheching sudo permission
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo privileges."
    exit 1
fi

###############################################################################################
### Monitoring USB drives in Linux using Wazuh                                              ###
### Ref: https://wazuh.com/blog/monitoring-usb-drives-in-linux-using-wazuh/                 ###
### Ref: oms.brotecs.com/issues/74467                                                       ###
###############################################################################################

# STEP 1: Create a file named usb_detect.sh in the /var/ossec/bin/ directory:
[ ! -f "/var/ossec/bin/usb_detect.sh" ] && sudo touch "/var/ossec/bin/usb_detect.sh"

# STEP 2: Add the following script to the /var/ossec/bin/usb_detect.sh file:
cat <<'EOF' >/var/ossec/bin/usb_detect.sh
#!/bin/bash

log_file="/var/log/usb_detect.json"
vendor="$ID_VENDOR"
model="$ID_MODEL"
serial="$ID_SERIAL_SHORT"
device="$DEVNAME"
devtype="$DEVTYPE"
hostname=$(hostname)

json="{\"hostname\":\"$hostname\",\"vendor\":\"$vendor\",\"model\":\"$model\",\"serial\":\"$serial\",\"device\":\"$device\",\"type\":\"$devtype\"}"

echo "$json" >> "$log_file"
EOF

# STEP 3: Change the file permission to ensure the script cannot be executed by others:
sudo chmod 700 /var/ossec/bin/usb_detect.sh

# STEP 4: Create a file usb-detect.rules in the /etc/udev/rules.d/ directory:
[ ! -f "/etc/udev/rules.d/usb-detect.rules" ] && sudo touch /etc/udev/rules.d/usb-detect.rules

# STEP 5: Add the following rule to the file:
cat <<'EOF' >/etc/udev/rules.d/usb-detect.rules
ACTION=="add", SUBSYSTEMS=="usb", RUN+="/var/ossec/bin/usb_detect.sh"
EOF

# STEP 6: Run the command below to reload the udev rules:
sudo udevadm control --reload

# STEP 7: Append the configuration below to the Wazuh agent /var/ossec/etc/ossec.conf file to collect the logs from the /var/log/usb_detect.json file:
# We will do this in Wazuh Shared agent configuration.

# STEP 8: Restart the Wazuh agent to apply the changes:
sudo systemctl restart wazuh-agent

echo "Script run successfully."
