#!/bin/bash

mac_cleanup_check () {
  # Path to the file containing the date
  file="$HOME/.df_sys_cleanup_marker"
  
  # Check if the file exists
  if [[ ! -f "$file" ]]; then
    # File not found, create it with the current date
    current_date=$(date "+%Y-%m-%d")
    echo "$current_date" > "$file"
    echo "Date file not found. Created the file with the current date: $current_date"
    exit 0
  fi
  
  # Read the date from the file
  stored_date=$(cat "$file")
  
  # Check if the date format is valid (strictly YYYY-MM-DD)
  if [[ ! "$stored_date" =~ ^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
    echo "Invalid date format in the file. Expected format: YYYY-MM-DD"
    exit 1
  fi
  
  # Get the current date and the date 30 days before today (compatible with macOS)
  current_date=$(date "+%Y-%m-%d")
  date_30_days_ago=$(date -v-30d "+%Y-%m-%d")
  
  # Compare the dates
  if [[ "$stored_date" < "$date_30_days_ago" ]] || [[ "$stored_date" = "$date_30_days_ago" ]]; then
    alert_message="${COL_RED}The last cleanup script execution was more than 30 days ago.${COL_RESET}"
    if [[ "$stored_date" = "$date_30_days_ago" ]]; then
        alert_message="${COL_RED}The last cleanup script execution was 30 days ago.${COL_RESET}"
    fi 
    
    echo "$alert_message"
    
    # Prompt the user to run the cleanup script
    echo -n "Do you want to run the cleanup script? (Y/N) [N]: "
    read user_input
    user_input=${user_input:-N}  # Default to N if no input is given
  
    # Manually convert to uppercase (compatible with older Bash versions)
    user_input=$(echo "$user_input" | tr '[:lower:]' '[:upper:]')
  
    if [[ "$user_input" == "Y" ]]; then
      echo "Running cleanup..."
      mac_cleanup
      # Update the date in the file to the current date
      echo "$current_date" > "$file"
      echo "Cleanup complete. Date updated to $current_date"
    else
      echo "No action taken."
    fi
  fi
}
