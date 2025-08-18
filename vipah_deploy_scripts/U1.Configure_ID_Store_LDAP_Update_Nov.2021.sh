#!/bin/bash

# Description: Configure ID Store
# Created by: B.K. Rhim
# Last Modification: Jan. 31, 2021

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
print_color "red" "LDAP Update.. Add \"user_loginid=cn\" "
print_color "default" ""
print_color "green" "####################################################"


TENANT_ADMIN_CLIENTID=$(kubectl get secret ${RELEASENAME}-ssp-secret-defaulttenantclient -n ${NAMESPACE} -o jsonpath="{.data.clientId}" | base64 --decode)
TENANT_ADMIN_CLIENTSECRET=$(kubectl get secret ${RELEASENAME}-ssp-secret-defaulttenantclient -n ${NAMESPACE} -o jsonpath="{.data.clientSecret}" | base64 --decode)
SSP_AT=$(curl -s --insecure -u "${TENANT_ADMIN_CLIENTID}:${TENANT_ADMIN_CLIENTSECRET}" --request POST --url "https://${SSP_FQDN}/default/oauth2/v1/token" --header "Content-Type: application/x-www-form-urlencoded" --data-urlencode "grant_type=client_credentials" --data-urlencode "scope=urn:iam:myscopes" | jq -r .access_token )

LDAP_CONFIG_ID=$(curl -s --insecure -L -X GET "https://${SSP_FQDN}/default/admin/v1/LDAPconfigs" -H 'Content-Type: application/json' -H "Authorization: Bearer ${SSP_AT}" | jq . | grep -vw -e '\[' -e '\]' | jq -r .ldapConfigId)

curl --insecure --request PUT "https://${SSP_FQDN}/default/admin/v1/LDAPconfigs/${LDAP_CONFIG_ID}" -H 'Content-Type: application/json'  -H "Authorization: Bearer ${SSP_AT}" -d '@./ldapconfig_nov.json'

curl -s --insecure -L -X GET "https://${SSP_FQDN}/default/admin/v1/LDAPconfigs" -H 'Content-Type: application/json' -H "Authorization: Bearer ${SSP_AT}" | jq .

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "LDAP Update Complete "
print_color "default" ""
print_color "green" "####################################################"

