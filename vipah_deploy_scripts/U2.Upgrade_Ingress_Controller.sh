#!/bin/bash


# Description: Deploy Ingress Controller
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


while true
do
        ingress_version_old=$(helm list -n ingress | grep ingress | awk '{ print $9} ')

        print_color "default" "####################################################"
        print_color "default" ""
        print_color "red"  "  Deploy Ingress Controller "
        print_color "default" ""
        print_color "green" "1. Upgrade Ingress 3.34.0 (VIP Auth Hub Nov 2021)"
        print_color "green" "2. Upgrade Ingress 4.15 (Auth Hub Jan 2022 with Kubernetes 1.22 above)"
        print_color "default" ""
        print_color "default" "####################################################"
        print_color "default" "              Existing Ingress Version : ${ingress_version_old}"
        print_color "default" "####################################################"
        print_color "default" ""
        print_color "default" ""
        read -p "Enter your choice: " choice

        case $choice in

                1) print_color "green" "Upgrade Ingress 3.34.0 (VIP Auth Hub Nov 2021 or Jan 2022 with Kubernetes 1.21 below)"
                        ingress_action="upgrade3"
                        ingress_version="3.34.0"
                        break
                        ;;
                2) print_color "green" "Upgrade Ingress 4.15 (VIP Auth Hub Jan 2022 with Kubernets 1.22 above)"
                        ingress_action="upgrade4"
                        ingress_version="4.15"
                        break
                        ;;
                *) continue
                        ;;
        esac
done


if [[ ( "${ingress_action}" == "upgrade3" ) && ( ! -z "${ingress_version_old}" ) ]]
then
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      helm repo update

      helm get values ingress-nginx -n ingress >ingress-override.yaml
      helm upgrade ingress-nginx -n ingress ingress-nginx/ingress-nginx --version=${ingress_version} -f ingress-override.yaml
elif [[ ( "${ingress_action}" == "upgrade3" ) ]]
then
      print_color "red"  "  ################################################## "
      print_color "red"  " " 
      print_color "red"  "   Upgrade Option is not available because there is no existing Ingress. "
      print_color "red"  " " 
      print_color "red"  "  ################################################## "
fi

is_higher_kubernetes_version=$(kubectl get node | grep -i ready|head -1 | awk '{print $5}' | grep -iE '1.22|1.23|1.24' | wc -l)

if [[ ( "${ingress_action}" == "upgrade4" ) && ( ! -z "${ingress_version_old}" ) && ( "${is_higher_kubernetes_version}" == "1" ) ]]
then
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      helm repo update

      helm get values ingress-nginx -n ingress >ingress-override.yaml
      helm upgrade ingress-nginx -n ingress ingress-nginx/ingress-nginx --version=${ingress_version} -f ingress-override.yaml
else
      print_color "red"  "  ################################################## "
      print_color "red"  " "
      print_color "red"  "   Upgrade Option is not available because there is no existing Ingress or unmatched kubernetes version. "
      print_color "red"  "   Node Kubernetes version: $(kubectl get node | grep -i ready|head -1 | awk '{print $5}')"
      print_color "red"  " "
      print_color "red"  "  ################################################## "
fi

print_color "default" "####################################################"
print_color "default" ""
print_color "green" "Get Ingress IP Address"
print_color "default" ""
print_color "default" "####################################################"

kubectl get pods -n ingress
kubectl get svc -n ingress 
helm list -n ingress
