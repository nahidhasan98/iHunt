#!/bin/bash

# linux
GOOS=linux go build -o wazuh/linux/master_ar_linux go_src/master_ar_linux.go
GOOS=linux go build -o wazuh/linux/ar_file_list_linux go_src/ar_file_list_linux.go
GOOS=linux go build -o wazuh/linux/ar_file_delete_linux go_src/ar_file_delete_linux.go

# macos
GOOS=darwin go build -o wazuh/macos/master_ar_mac go_src/master_ar_mac.go
GOOS=darwin go build -o wazuh/macos/ar_file_list_mac go_src/ar_file_list_mac.go
GOOS=darwin go build -o wazuh/macos/ar_file_delete_mac go_src/ar_file_delete_mac.go

# windows
GOOS=windows go build -o wazuh/windows/master_ar_windows.exe go_src/master_ar_windows.go
GOOS=windows go build -o wazuh/windows/ar_file_list_windows.exe go_src/ar_file_list_windows.go
GOOS=windows go build -o wazuh/windows/ar_file_delete_windows.exe go_src/ar_file_delete_windows.go

echo "Built successfully."
