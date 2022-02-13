#!/bin/bash
az acr webhook delete -n 'jenkinswebappdemo' -r '...'
terraform destroy -auto-approve
