param (
    [string]$WAZUH_AGENT_NAME,
    [string]$ENVIRONMENT
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
if (-not $WAZUH_AGENT_NAME -or -not $ENVIRONMENT) {
    Write-Host "Usage: windows_agent.ps1 <iCyberHunt_AGENT_NAME> <environment:prod/dev>"
    Pause
    Exit
}

$WAZUH_MANAGER = if ($ENVIRONMENT -eq "dev") {
    "43.240.100.76"
}
elseif ($ENVIRONMENT -eq "prod") {
    "202.191.121.110"
}
else {
    Write-Host "Unknown environment: $ENVIRONMENT"
    Exit
}

# Check if the system is 32-bit or 64-bit
if ([Environment]::Is64BitOperatingSystem) {
    $OS = "64BIT"
} else {
    $OS = "32BIT"
}

# Define log file paths based on the system architecture
if ($OS -eq "32BIT") {
    $BASE_PROGRAM_FILES = "${env:ProgramFiles}"
} elseif ($OS -eq "64BIT") {
    $BASE_PROGRAM_FILES = "${env:ProgramFiles(x86)}"
}

# Run the following commands to download and install the agent:
Write-Output "Downloading iCyberHunt agent..."
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.7.3-1.msi -OutFile "${env:tmp}\wazuh-agent"
Write-Output "Downloaded iCyberHunt agent"

Write-Output "Installing iCyberHunt agent..."
msiexec.exe /i "${env:tmp}\wazuh-agent" /q WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_AGENT_GROUP='default,Windows' WAZUH_AGENT_NAME="$WAZUH_AGENT_NAME" WAZUH_REGISTRATION_SERVER="$WAZUH_MANAGER"
Write-Output "Installed iCyberHunt agent"

# sleep the script for 3 seconds
Start-Sleep -Seconds 3

# Remove the downloaded MSI file after installation
Remove-Item -Path "${env:tmp}\wazuh-agent" -Force

# STEP 2:
# Modifying Wazuh agent keyword to iCyberHunt agent
$ossecFile = "$BASE_PROGRAM_FILES\ossec-agent\ossec.conf"

# Read the content of the file
$content = Get-Content -Path $ossecFile

# Process each line of the content
$newContent = $content | ForEach-Object {
    # Replace lines starting with 'Wazuh - Agent - Default configuration'
    if ($_ -match '^\s*Wazuh - Agent - Default configuration') {
        $_ -replace '^\s*Wazuh - Agent - Default configuration', '  iCyberHunt - Agent - Default configuration'
    }
    # Exclude lines starting with 'More info' or 'Mailing list'
    elseif ($_ -notmatch '^\s*(More info|Mailing list)') {
        $_  # Output unchanged line
    }
}

# Write the updated content back to the file
$newContent | Set-Content -Path $ossecFile

# Start the agent:
# We will start the agent after modifying the configuration

# STEP 3:
# Enabling the remote commands on agent:
$LOCAL_INTERNAL_CONF_FILE = "$BASE_PROGRAM_FILES\ossec-agent\local_internal_options.conf"
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

# STEP 4:
# Creating log file for custom ar (that will be captured by wazuh)
New-Item -Path "$BASE_PROGRAM_FILES\ossec-agent\active-response\custom_ar.log" -ItemType File -Force > $null

Write-Output "Downloading necesasry ar files..."
# STEP 5:
# Getting file_list ar
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nahidhasan98/iHunt/main/bin/wazuh/windows/ar_file_list_windows.exe" -OutFile "$BASE_PROGRAM_FILES\ossec-agent\active-response\bin\ar_file_list_windows.exe";

# STEP 6:
# Getting master ar
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nahidhasan98/iHunt/main/bin/wazuh/windows/master_ar_windows.exe" -OutFile "$BASE_PROGRAM_FILES\ossec-agent\active-response\bin\master_ar_windows.exe";

# STEP 7:
# Getting file_delete ar
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nahidhasan98/iHunt/main/bin/wazuh/windows/ar_file_delete_windows.exe" -OutFile "$BASE_PROGRAM_FILES\ossec-agent\active-response\bin\ar_file_delete_windows.exe";

Write-Output "Download done."

# Start the agent:
Write-Output "Starting iCyberHunt agent..."
net.exe START WazuhSvc
Write-Output "Started iCyberHunt agent"

Write-Output "Script run successfully."

# Keep the PowerShell window open
Pause
