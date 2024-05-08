package main

import (
	"fmt"
	"log"
	"os"
	"strings"
	"time"
)

func main() {
	// Directory path to list files
	dirPath := `C:\Program Files (x86)\ossec-agent\active-response\bin`

	// Path to the log file
	logFilePath := `C:\Program Files (x86)\ossec-agent\active-response\custom_ar.log`

	// Get list of files in the directory
	fileInfos, err := os.ReadDir(dirPath)
	if err != nil {
		log.Fatalf("Failed to read directory: %v", err)
	}

	// Extract file names from fileInfos
	var fileNames []string
	for _, fileInfo := range fileInfos {
		fileNames = append(fileNames, fileInfo.Name())
	}

	// Join file names with comma separator
	fileList := strings.Join(fileNames, ",")

	// Get the current time
	currentTime := time.Now().Format("2006-01-02 15:04:05")
	logMessage := fmt.Sprintf("[%s] AR_FILE_LIST_WINDOWS: %s\n", currentTime, fileList)

	// Open the log file for appending (create if not exists)
	file, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to open log file: %v", err)
	}
	defer file.Close()

	// Write the file list to the log file
	if _, err := file.WriteString(logMessage); err != nil {
		log.Fatalf("Failed to write to log file: %v", err)
	}

	fmt.Printf("File list written successfully to %s\n", logFilePath)
}
