#!/bin/bash

# Description: Delete Service in Google Cluster
# Created by: B.K. Rhim
# Last Modification: Feb. 15, 2021

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
print_color "red" "Deleting Sample App Service "
print_color "default" ""
print_color "green" "####################################################"

helm uninstall ${SA_RELEASENAME} -n ${SA_NAMESPACE}
kubectl delete ns ${SA_NAMESPACE}

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Deleting VIP Auth Hub Infra and VIP Auth Hub Service "
print_color "default" ""
print_color "green" "####################################################"

SSP_HELM_SERVICE_LIST=$(helm list -n "$NAMESPACE" | awk '{print $1}' | sed '1d')

for SSP_HELM_SERVICE in $SSP_HELM_SERVICE_LIST
do
  helm uninstall "${SSP_HELM_SERVICE}" -n "${NAMESPACE}"
done

echo "Deleting name space ${NAMESPACE} "
kubectl delete ns "$NAMESPACE"

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Deleting VIP Auth Hub Prometheus Adopter"
print_color "default" ""
print_color "green" "####################################################"

helm uninstall ssp-prometheus-adapter -n prometheus-adapter
kubectl delete ns prometheus-adapter
