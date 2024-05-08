param (
	[string]$WAZUH_AGENT_NAME
)

# Check if the script is running with admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
	Write-Host "Script not running with admin privileges. Please Run as Administrator."
	Pause
	Exit
}

# STEP 1:
# Check if WAZUH_AGENT_NAME argument is provided
if (-not $WAZUH_AGENT_NAME) {
	Write-Host "Usage: windows_agent.ps1 <WAZUH_AGENT_NAME>"
	Pause
	Exit
}

# Run the following commands to download and install the agent:
Write-Output "Downloading Wazuh agent..."
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.7.3-1.msi -OutFile ${env.tmp}\wazuh-agent;
Write-Output "Downloaded Wazuh agent"

Write-Output "Installing Wazuh agent..."
msiexec.exe /i ${env.tmp}\wazuh-agent /q WAZUH_MANAGER='43.240.100.76' WAZUH_AGENT_GROUP='default,Windows' WAZUH_AGENT_NAME="$WAZUH_AGENT_NAME" WAZUH_REGISTRATION_SERVER='43.240.100.75'
Write-Output "Installed Wazuh agent"

# sleep the script for 3 seconds
Start-Sleep -Seconds 3

# Start the agent:
# We will start the agent after modifying the configuration

# STEP 2:
# Enabling the remote commands on agent:
$LOCAL_INTERNAL_CONF_FILE = "C:\Program Files (x86)\ossec-agent\local_internal_options.conf"
$linesToAdd = @"
logcollector.remote_commands=1
wazuh_command.remote_commands=1
"@
# Check if the file exists
if (Test-Path $LOCAL_INTERNAL_CONF_FILE) {
	# Append the lines to the file
	Add-Content -Path $LOCAL_INTERNAL_CONF_FILE -Value $linesToAdd -Encoding UTF8
}
else {
	Write-Host "Error: File $LOCAL_INTERNAL_CONF_FILE not found."
}

# STEP 3:
# Downloading ar file list (ar_file_list_windowx.exe)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nahidhasan98/iHunt/main/wazuh/windows/ar_file_list_windows.exe" -OutFile "C:\Program Files (x86)\ossec-agent\active-response\bin\ar_file_list_windows.exe";

# Creating log file for ar_file_list that will be captured by wazuh
New-Item -Path "C:\Program Files (x86)\ossec-agent\active-response\custom_ar.log" -ItemType File -Force > $null

# STEP 4:
# todo: Creating master ar

# Start the agent:
Write-Output "Starting Wazuh agent..."
net.exe START WazuhSvc
Write-Output "Started Wazuh agent"

Write-Output "Script run successfully."

# Keep the PowerShell window open
Pause
