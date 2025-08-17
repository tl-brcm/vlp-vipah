#!/bin/bash

# Description: Delete Google Kubernete Clusteer
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
print_color "red" "Deleting Google Kubernetes Cluster Service ($GCS_CLUSTER_NAME) --zone='us-west1-b' "
print_color "default" ""
print_color "green" "####################################################"

gcloud container clusters delete ${GCS_CLUSTER_NAME} --zone='us-west1-b'

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Google Cluster ($GCS_CLUSTER_NAME) is deleted"
print_color "default" ""
print_color "green" "####################################################"
