package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
)

type Args struct {
	Parameters struct {
		ExtraArgs []string `json:"extra_args"`
	} `json:"parameters"`
}

func getFileName(inputJSON string) string {
	logFilePath := `C:\Program Files (x86)\ossec-agent\active-response\custom_ar.log`

	// Open the log file for appending (create if not exists)
	file, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to open log file: %v", err)
	}
	defer file.Close()

	// Parse the JSON input
	var args Args
	err = json.Unmarshal([]byte(inputJSON), &args)
	if err != nil {
		// Write the file list to the log file
		file.WriteString("Error: Failed to parse JSON input: " + err.Error() + "\n")
		os.Exit(1)
	}

	// Extract URL from the parameters
	if len(args.Parameters.ExtraArgs) == 0 {
		// Write the file list to the log file
		file.WriteString("Error: Unable to retrieve args" + "\n")
		os.Exit(1)
	}

	return args.Parameters.ExtraArgs[0]
}

func main() {
	logFilePath := `C:\Program Files (x86)\ossec-agent\active-response\custom_ar.log`

	// Open the log file for appending (create if not exists)
	file, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to open log file: %v", err)
	}
	defer file.Close()

	// Read input JSON from stdin (assuming JSON is provided as a single line)
	var inputJSON string
	fmt.Scanln(&inputJSON)

	filePath := getFileName(inputJSON)
	fmt.Println(filePath)

	filePath = "C:\\Program Files (x86)\\ossec-agent\\active-response\\bin\\" + filePath
	// Attempt to remove the file
	err = os.Remove(filePath)
	if err != nil {
		// If there was an error deleting the file, handle it
		file.WriteString("Error deleting file: " + err.Error() + "\n")
		os.Exit(1)
	}

	// If deletion was successful, inform the user
	file.WriteString("File \"" + filePath + "\" has been deleted successfully." + "\n")
}
