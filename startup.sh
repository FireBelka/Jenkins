#!/bin/bash
#az acr login -n testRegK8s
#az account list
terraform apply -auto-approve
VAR1=$(az webapp deployment container config --enable-cd true --name 'web-app-from-jenkins' -s staging --resource-group 'web-rg'  | jq '.CI_CD_URL' | tr -d '"')
az acr webhook create -n 'jenkinswebappdemo' -r '...' --uri $VAR1 --actions push --scope <repo>:latest
