#!/bin/bash

# Usage: ./upload-samples.sh <storage_account_name>

if [ -z "$1" ]; then
  echo "Usage: ./upload-samples.sh <storage_account_name>"
  exit 1
fi

storage_account_name=$1

az storage blob upload-batch --account-name "$storage_account_name" -d inputs -s ../samples
