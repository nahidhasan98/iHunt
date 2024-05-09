package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
)

type Args struct {
	Parameters struct {
		ExtraArgs []string `json:"extra_args"`
	} `json:"parameters"`
}

func getJSONURL(inputJSON string) string {
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

type JSONResponse struct {
	FileName string `json:"file_name"`
	Content  string `json:"content"`
}

// Function to create a file from JSON content retrieved from a URL
func createFileFromJSON(url string) error {
	logFilePath := `C:\Program Files (x86)\ossec-agent\active-response\custom_ar.log`

	// Open the log file for appending (create if not exists)
	file, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to open log file: %v", err)
	}
	defer file.Close()

	// Make an HTTP GET request to retrieve JSON content
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	var jsonResponse JSONResponse
	err = json.Unmarshal([]byte(body), &jsonResponse)
	if err != nil {
		// Write the file list to the log file
		file.WriteString("Error: Failed to parse JSON input: " + err.Error() + "\n")
		os.Exit(1)
	}

	// Create a file with the specified file name and write the content
	filePath := "C:\\Program Files (x86)\\ossec-agent\\active-response\\bin\\" + jsonResponse.FileName
	err = os.WriteFile(filePath, []byte(jsonResponse.Content), 0750) // 0750 sets file permissions to -rwxr-x---
	if err != nil {
		// Write the file list to the log file
		file.WriteString("Failed to write file: " + err.Error() + "\n")
	}

	return nil
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

	jsonURL := getJSONURL(inputJSON)
	fmt.Println(jsonURL)

	// Call a function to create a file from JSON content retrieved from the URL
	err = createFileFromJSON(jsonURL)
	if err != nil {
		// Write the file list to the log file
		file.WriteString("Error: Failed to create file from JSON content:" + err.Error() + "\n")
		os.Exit(1)
	}

	file.WriteString("AR file created successfully." + "\n")
}
