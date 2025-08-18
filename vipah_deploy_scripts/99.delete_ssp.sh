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

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Deleting Sample App Service "
print_color "default" ""
print_color "green" "####################################################"

helm uninstall ${SA_RELEASENAME} -n ${SA_NAMESPACE}
kubectl delete ns ${SA_NAMESPACE}


print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Deleting VIP Auth Hub Service "
print_color "default" ""
print_color "green" "####################################################"

SSP_HELM_SERVICE_LIST=$(helm list -n "$NAMESPACE" | awk '{print $1}' | sed '1d')

for SSP_HELM_SERVICE in $SSP_HELM_SERVICE_LIST
do
  helm uninstall "${SSP_HELM_SERVICE}" -n "${NAMESPACE}"
done

echo "Deleting name space $NAMESPACE"
kubectl delete ns "$NAMESPACE"

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Deleting Logging Service "
print_color "default" ""
print_color "green" "####################################################"

helm uninstall kibana -n logging
helm uninstall elasticsearch -n logginga
helm uninstall elastic-operator -n logginga
kubectl delete ns logging 

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Deleting Monitoring Service "
print_color "default" ""
print_color "green" "####################################################"

helm uninstall prometheus-operator -n monitoring
helm uninstall grafana-operator -n monitoring
kubectl delete ns monitoring 

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Deleting Tracing Service "
print_color "default" ""
print_color "green" "####################################################"

helm uninstall jaeger-operator -n tracing
kubectl delete ns tracing  

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Deleting Ingress Service "
print_color "default" ""
print_color "green" "####################################################"

helm uninstall ingress-nginx -n ingress
kubectl delete ns ingress   
