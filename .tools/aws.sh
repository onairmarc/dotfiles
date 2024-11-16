get_aws_secret() {
  # Check if the secret name is provided as an argument
  if [ -z "$1" ]; then
    echo "Error: Secret name or ARN is required."
    return 1
  fi

  # Replace with your actual secret name or ARN
  local secret_name=$1

  # Use AWS CLI to get the secret value and store the result in the json variable.
  json=$(aws secretsmanager get-secret-value --secret-id "$secret_name" --query '{ARN: ARN, Name: Name, VersionId: VersionId, SecretString: SecretString, VersionStages: VersionStages, CreatedDate: CreatedDate}' --output json)

  # Check if the AWS command was successful
  if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve secret from AWS Secrets Manager."
    return 1
  fi

  # Extract the SecretString content using jq
  secret_string=$(echo "$json" | jq -r '.SecretString')

  # Remove control characters (U+0000 to U+001F) from the SecretString
  secret_string_clean=$(echo "$secret_string" | tr -d '\000-\037')

  # Ensure the cleaned secret string is valid JSON
  if ! echo "$secret_string_clean" | jq empty; then
    echo "Error: Invalid SecretString format after cleaning."
    return 1
  fi

  # Iterate over the cleaned SecretString content, extracting key-value pairs
  echo "$secret_string_clean" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' | while IFS= read -r line; do
    key=$(echo "$line" | cut -d= -f1) # Extract the key name
    export "$line"                     # Export the key=value as an environment variable
  done

  return 0
}