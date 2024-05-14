#!/bin/bash

# linux 64bit
GOOS=linux GOARCH=amd64 go build -o bin/wazuh/linux/master_ar_linux src/go/linux/master_ar_linux.go
GOOS=linux GOARCH=amd64 go build -o bin/wazuh/linux/ar_file_list_linux src/go/linux/ar_file_list_linux.go
GOOS=linux GOARCH=amd64 go build -o bin/wazuh/linux/ar_file_delete_linux src/go/linux/ar_file_delete_linux.go

# macos 64bit
GOOS=darwin GOARCH=amd64 go build -o bin/wazuh/macos/master_ar_mac src/go/macos/master_ar_mac.go
GOOS=darwin GOARCH=amd64 go build -o bin/wazuh/macos/ar_file_list_mac src/go/macos/ar_file_list_mac.go
GOOS=darwin GOARCH=amd64 go build -o bin/wazuh/macos/ar_file_delete_mac src/go/macos/ar_file_delete_mac.go

# windows 64bit
GOOS=windows GOARCH=amd64 go build -o bin/wazuh/windows/master_ar_windows.exe src/go/windows/master_ar_windows.go
GOOS=windows GOARCH=amd64 go build -o bin/wazuh/windows/ar_file_list_windows.exe src/go/windows/ar_file_list_windows.go
GOOS=windows GOARCH=amd64 go build -o bin/wazuh/windows/ar_file_delete_windows.exe src/go/windows/ar_file_delete_windows.go

echo "Built successfully."
