#!/bin/bash

echo "Checking prerequisites for deploying the Resource Catalogue..."
source ../common/utils.sh

# Check for kubectl
if command_exists kubectl; then
  echo "kubectl is installed."
  # Check if kubectl can connect to your cluster
  if kubectl cluster-info; then
    echo "kubectl is configured to interact with your cluster."
  else
    echo "kubectl cannot connect to your cluster. Please check your configuration."
    exit 1
  fi
else
  echo "kubectl is not installed. Please install kubectl."
  exit 1
fi

# Check for Helm
if command_exists helm; then
  echo "Helm is installed."
  # Check Helm version
  helm_version=$(helm version --short | cut -d '.' -f 1 | sed 's/[^0-9]*//g')
  if [ "$helm_version" -ge 3 ]; then
    echo "Helm version is $helm_version, which is suitable for deployment."
  else
    echo "Helm version is less than 3. Please upgrade Helm."
    exit 1
  fi
else
  echo "Helm is not installed. Please install Helm."
  exit 1
fi

# Optional check for Python or python3
if command_exists python || command_exists python3; then
  echo "Python is installed."
else
  echo "Python is not installed, which is optional but recommended for PyCSW interaction."
fi

echo -e "\nAll prerequisite checks passed successfully. ✅"
