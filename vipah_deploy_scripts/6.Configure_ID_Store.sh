#!/bin/bash

# Description: Configure ID Store
# Created by: B.K. Rhim
# Last Modification: Oct 2023

DIRNAME="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"
source ${DIRNAME}/0.gks_env.sh

NC="\033[0m"

function print_color(){
  case $1 in
    "green") COLOR="\033[0;32m" ;;
    "red")  COLOR="\033[0;31m" ;;
    "blue")  COLOR="\033[0;34m" ;;
    *) COLOR="\033[0m" ;;
  esac
  echo -e "${COLOR} $2 ${NC}"
}

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Configuring ID Store"
print_color "default" ""
print_color "green" "####################################################"

# First get the tenant ID and from there get the access token to call the rest API for futher confiugrations. 
TENANT_ADMIN_CLIENTID=$(kubectl get secret ${RELEASENAME}-ssp-secret-defaulttenantclient -n ${NAMESPACE} -o jsonpath="{.data.clientId}" | base64 --decode)
TENANT_ADMIN_CLIENTSECRET=$(kubectl get secret ${RELEASENAME}-ssp-secret-defaulttenantclient -n ${NAMESPACE} -o jsonpath="{.data.clientSecret}" | base64 --decode)
SSP_AT=$(curl -s --insecure -u "${TENANT_ADMIN_CLIENTID}:${TENANT_ADMIN_CLIENTSECRET}" --request POST --url "https://${SSP_FQDN}/default/oauth2/v1/token" --header "Content-Type: application/x-www-form-urlencoded" --header "x-tenant-name: default" --data-urlencode "grant_type=client_credentials" --data-urlencode "scope=urn:iam:myscopes" | jq -r .access_token )

print_color "default" ""
print_color "green" "CORS Setting to Reflect Sample Application's FQDN"
print_color "default" ""

# Update the access token based on our domain
sed 's/\[SA_FQDN\]/'${SA_FQDN}'/g' allow_origin_template.json > allow_origin.json

curl --insecure -L -X PATCH "https://${SSP_FQDN}/default/admin/v1/Configs" -H 'Content-Type: application/json' -H "Authorization: Bearer ${SSP_AT}" -H "x-tenant-name: default" -d '@./allow_origin.json'

print_color "default" ""
print_color "green" "Add VIP Certificate for VIP PUSH"
print_color "default" ""

curl --insecure -L -X POST "https://${SSP_FQDN}/default/admin/v1/VIPConfiguration" -H 'Content-Type: application/json' -H "Authorization: Bearer ${SSP_AT}" -H "x-tenant-name: default" -d '@./vipCert.json'

print_color "green" "####################################################"
print_color "default" ""
print_color "default" "LDAP IP Address: ${IPADDRESS} "
print_color "red" "Complete ID Store setup.. Please access the Sample App and validate the login erussell/password."
print_color "red" "Sample App URL: https://${SA_FQDN}/sample-app/ "
print_color "default" ""
print_color "green" "####################################################"