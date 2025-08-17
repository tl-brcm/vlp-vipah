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
        print_color "green" "1. Ingress 4.11.2 deploy  "    
        print_color "green" "2. Ingress 4.0.16 deploy "
        print_color "blue" "3. Upgrade Ingress 4.11.2 "

        print_color "default" ""
        print_color "default" "####################################################"
        print_color "default" "              Existing Ingress Version : ${ingress_version_old}"
        print_color "default" "####################################################"
        print_color "default" ""
        print_color "default" ""
        read -p "Enter your choice: " choice

        case $choice in

                1) print_color "green" "Ingress 4.11.2 deploy"
                        ingress_action="install"
                        ingress_version="4.11.2"
			ingress_name_space="ingress"
                        break
                        ;; 
                2) print_color "green" "Ingress 4.0.16 deploy"
                        ingress_action="install"
                        ingress_version="4.0.16"
			ingress_name_space="ingress"
                        break
                        ;;
                3) print_color "green" "Upgrade Ingress 4.11.2"
                        ingress_action="upgrade"
                        ingress_version="4.11.2"
			ingress_name_space="ingress"
                        break
                        ;;
                *) continue
                        ;;
        esac
done

if [[ ("${ingress_action}" == "install") && ( -z "${ingress_version_old}") ]] ;
then

	kubectl create ns "${ingress_name_space}"

	kubectl create secret docker-registry docker-hub-reg-pullsecret -n ${ingress_name_space} \
	--docker-server="https://index.docker.io/v2/" \
	--docker-username="${DOCKER_USERNAME}" \
	--docker-password="${DOCKER_PASSWORD}"

	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update

	helm install ingress-nginx -n ${ingress_name_space} ingress-nginx/ingress-nginx \
	--set-string controller.config.use-forwarded-headers="true" \
	--set imagePullSecrets[0].name=docker-hub-reg-pullsecret \
        --set controller.allowSnippetAnnotations=true \
	--set-string controller.config.annotation-value-word-blocklist="load_module\,lua_package\,_by_lua\,location\,root\,proxy_pass\,serviceaccount\,{\,}\,\'\,\\\\" \
        --set controller.service.externalTrafficPolicy="Local" \
	--version=${ingress_version}

 
elif [[ ( "${ingress_action}" == "upgrade" ) && ( ! -z "${ingress_version_old}" ) ]]
then

	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update

	helm get values ingress-nginx -n ingress >ingress-override.yaml

        helm upgrade ingress-nginx -n ingress ingress-nginx/ingress-nginx -f ingress-override.yaml \
        --version=${ingress_version}

else
      print_color "red"  "  ################################################## "
      print_color "red"  " " 
      print_color "red"  "  Provided option is not applicable. Please select upgrade option when you already have Ingress "
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
