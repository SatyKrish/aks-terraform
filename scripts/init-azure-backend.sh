#!/bin/bash
RESOURCE_GROUP_NAME=saty-terraform-rg
STORAGE_ACCOUNT_NAME=satyterraformbackend
ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)
export ARM_ACCESS_KEY=$ACCOUNT_KEY