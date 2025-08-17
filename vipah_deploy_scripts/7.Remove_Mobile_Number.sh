#!/bin/bash

# Description: Remove Mobile number from LDAP Server (Please open a firewall before doing this step)
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
print_color "red" "Initialize Mobile Phone number for testing in LDAP Directory"
print_color "red" "Initial "
print_color "default" ""
print_color "green" "####################################################"


# LDAP_IP_ADDRESS=$(kubectl get svc -n ${SA_NAMESPACE} | grep dir | awk '{ print $4 }')
LDAP_IP_ADDRESS=127.0.0.1
echo "LDAP IP Address" $LDAP_IP_ADDRESS

PORT=1389
ldapsearch -H ldap://localhost:${PORT} -x -o ldif-wrap=no dn | awk 'BEGIN{print "version: 1\n"}/^dn:/{print;print "changetype: modify\nreplace: mail\n-\nreplace: telephoneNumber\n-\n"}' | ldapmodify -H ldap://localhost:${PORT} -x

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Mobile Phone is removed from the user directory for the testing"
print_color "default" ""
print_color "green" "####################################################"

