#!/bin/bash

# Description: Delete Service in Google Cluster
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


kubectl_version="$(kubectl version --short)"
helm_version="$(helm version)"
jq_version="$(jq --version)"
git_version="$(git --version)"

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Check VIP Auth Hub Enivronment "
print_color "default" ""
print_color "red" "Kubelet Version : "
print_color "green" "${kubectl_version}"
print_color "default" ""
print_color "red" "Helm Version : "
print_color "green" "${helm_version}"
print_color "default" ""
print_color "red" "GIT Version : "
print_color "green" "${git_version}"
print_color "default" ""
print_color "red" "Python Version : "
print_color "green" "$(python --version)"
print_color "default" ""
print_color "red" "JQ Version : "
print_color "green" "${jq_version}"
print_color "default" ""

gcs_info="$(gcloud config list)"
get_node="$(kubectl get nodes)"
get_ingress_info="$(kubectl get svc -n ingress)"
logging_pod="$(kubectl get pods -l app=elasticsearch-master -n logging)"
kibana_service="$(kubectl get pods -l app=kibana -n logging)"
jaeger_service="$(kubectl get pods -n tracing)"
monitoring_service="$(kubectl get pods -n monitoring)"

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Google Cloud Service Info "
print_color "green" "${gcs_info}"
print_color "default" ""
print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Kubernete Information "
print_color "default" ""
print_color "red" "Availabe Node : Should be more than 3 nodes "
print_color "green" "${get_node}"
print_color "default" ""
print_color "red" "Ingress : Check ingress Controler Service and external IP address"
print_color "green" "${get_ingress_info}"
print_color "default" ""

helm_list=$(helm list -A)
print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Helm List "
print_color "default" ""
print_color "green" "${helm_list}"
print_color "default" ""
print_color "green" "####################################################"
print_color "default" ""

ssp_service="$(kubectl get pod -n ${NAMESPACE})"

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "VIP Auth Hub Service pods"
print_color "green" "${ssp_service}"
print_color "default" ""

sample_service="$(kubectl get pod -n ${SA_NAMESPACE})"

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Sample Service pod: 2 pod are running status. 1 pod is sample app and the other one is sample ldap."
print_color "green" "${sample_service}"
print_color "default" ""



IPADDRESS="$(kubectl get svc -n ingress | grep -i LoadBalancer | awk '{ print $4 }' )"

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Check network connection between kubectl client (ex: CentOS) and Kubernetes environemnt (ex: Google Cloud)"
print_color "default" ""
print_color "green" " wget https://${SSP_FQDN}, When the client cannot connect to VIP Auth Service, please add ${IPADDRESS}   ${SSP_FQDN} in the DNS server or hosts file where the script is running"
print_color "default" ""
print_color "default" " wget -nv https://${SSP_FQDN}/default/ui/v1/adminconsole/ "
wget -nv https://${SSP_FQDN}/default/ui/v1/adminconsole/ 
print_color "default" ""
print_color "default" ""


TENANT_ADMIN_CLIENTID=$(kubectl get secret ${RELEASENAME}-ssp-secret-defaulttenantclient -n ${NAMESPACE} -o jsonpath="{.data.clientId}" | base64 --decode)
TENANT_ADMIN_CLIENTSECRET=$(kubectl get secret ${RELEASENAME}-ssp-secret-defaulttenantclient -n ${NAMESPACE} -o jsonpath="{.data.clientSecret}" | base64 --decode)
SSP_AT=$( curl -s --insecure -u "${TENANT_ADMIN_CLIENTID}:${TENANT_ADMIN_CLIENTSECRET}" --request POST --url "https://${SSP_FQDN}/default/oauth2/v1/token" --header "Content-Type: application/x-www-form-urlencoded" --data-urlencode "grant_type=client_credentials" --data-urlencode "scope=urn:iam:myscopes" | jq -r .access_token )


print_color "green" "####################################################"
print_color "default" ""
print_color "red" " CORS Setting Check"
print_color "default" ""
print_color "green" "$(if [ ! -z "${SSP_AT}" ]; then curl -s --insecure -L -X GET "https://${SSP_FQDN}/default/admin/v1/Configs" -H 'Content-Type: application/json' -H "Authorization: Bearer ${SSP_AT}" | jq . | grep -A 2 'allowedOrigins' ; else echo "***** ERROR: SSP Access Token is not availabe ************"; fi)"
print_color "default" ""
print_color "red" " LDAP Store Information in VIP Auth Hub"
print_color "default" ""
print_color "green" "$(if [ ! -z "${SSP_AT}" ]; then curl -s --insecure -L -X GET "https://${SSP_FQDN}/default/admin/v1/LDAPconfigs" -H 'Content-Type: application/json' -H "Authorization: Bearer ${SSP_AT}" | jq . ; else echo "***** ERROR: SSP Access Token is not availabe ************"; fi)"
print_color "default" ""
print_color "green" "####################################################"