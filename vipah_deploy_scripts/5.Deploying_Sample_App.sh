#!/bin/bash

# Description: Deploy VIP AuthHub Service
# Created by: B.K. Rhim
# Last Modification: June 2023

DIRNAME="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"
source ${DIRNAME}/0.gks_env_release.sh

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
sample_app_version_old=$(helm list -n ${SA_NAMESPACE} | grep -i sample | awk '{ print $9} ')

        print_color "default" "####################################################"
        print_color "default" ""
        print_color "red" "  Deploying VIP Auth Hub Sample App. Please select the version "
        print_color "default" ""
        print_color "green" "1. Install VIP Auth Hub Sample App $SSP_VERSION (Sample App build $SSP_VERSION_FULL)"
        print_color "blue" "2. Upgrade VIP Auth Hub Sample App $SSP_VERSION (Sample App build $SSP_VERSION_FULL)"
        print_color "default" ""
        print_color "default" "####################################################"
        print_color "default" "####################################################"
        print_color "default" "  Existing Sample App version: ${sample_app_version_old}"
        print_color "default" "####################################################"
        print_color "default" ""
        print_color "default" ""
        read -p "Enter your choice: " choice

        case $choice in
                1) print_color "green" "Install VIP Auth Hub Sample App $SSP_VERSION"
                        sample_app_action="install"
                        sample_app_version=$SSP_VERSION_FULL
                        break
                        ;;
                2) print_color "green" "Upgrade VIP Auth Hub Sample App $SSP_VERSION"
                        sample_app_action="upgrade"
                        sample_app_version=$SSP_VERSION_FULL
                        sample_app_version_old=$(helm list -n ${SA_NAMESPACE} | grep ${SA_RELEASENAME} | awk '{print $10}')
                        break
                        ;;
                *) continue
                        ;;
        esac
done

if [ "${sample_app_action}" == "install" ] 
then

        kubectl create ns "${SA_NAMESPACE}"

	kubectl create secret docker-registry ssp-registrypullsecret -n ${SA_NAMESPACE} \
        --docker-server="https://securityservices.packages.broadcom.com/" \
        --docker-username="${SSP_USERNAME}" \
        --docker-password="${SSP_CREDENTIAL}" \
        --docker-email="${EMAIL_ADDRESS}"

        kubectl create secret tls sampleapp-general-tls --cert "${SA_CERTFILE}" --key "${SA_KEYFILE}" -n "${SA_NAMESPACE}"

        SA_CLIENTID=$(kubectl get secret ${RELEASENAME}-ssp-secret-democlient -n "${NAMESPACE}" -o jsonpath="{.data.clientId}" | base64 --decode)
        SA_CLIENTSECRET=$(kubectl get secret ${RELEASENAME}-ssp-secret-democlient -n "${NAMESPACE}" -o jsonpath="{.data.clientSecret}" | base64 --decode)

        helm repo add "${HELM_REPO}" "${HELM_REPO_URL}"
        helm repo update

        print_color "green" "VIP Auth Hub Sample Service install."

	helm install "${SA_RELEASENAME}" -n "${SA_NAMESPACE}" ${HELM_REPO}/ssp-sample-app \
	--render-subchart-notes \
	--set ssp.serviceUrl="${SSP_URL}" \
	--set ssp.clientId="${SA_CLIENTID}" \
	--set ssp.clientSecret="${SA_CLIENTSECRET}" \
	--set ingress.host="${SA_FQDN}" \
	--set ingress.tls.host="${SA_FQDN}" \
	--set ingress.tls.secretName=sampleapp-general-tls \
	--set ssp-symantec-dir.service.type=NodePort \
	--set ssp-symantec-dir.service.servicePort=389 \
	--set global.registry.existingSecrets[0].name="ssp-registrypullsecret" \
        --version=${sample_app_version} \
        --timeout '20m' \
	--wait

        next_step="Please proceed the next step. 6./Configure_ID_Store.sh"

elif [[ ( "${sample_app_action}" == "upgrade" ) && ( ! -z "${sample_app_version_old}" ) ]]
then

        print_color "red" "VIP Auth Hub Sample App Upgrade "

        print_color "green" "After deleting existig ssp-registrypullsecret and create it again. "

	kubectl delete secret ssp-registrypullsecret -n "${SA_NAMESPACE}"
	
        kubectl create secret docker-registry ssp-registrypullsecret -n ${SA_NAMESPACE} \
        --docker-server="https://securityservices.packages.broadcom.com/" \
        --docker-username="${SSP_USERNAME}" \
        --docker-password="${SSP_CREDENTIAL}" \
        --docker-email="${EMAIL_ADDRESS}"

        print_color "green" "After deleting existig sampleapp-general-tls and create it again. "

	kubectl delete secret sampleapp-general-tls -n "${SA_NAMESPACE}"

        kubectl create secret tls sampleapp-general-tls --cert "${SA_CERTFILE}" --key "${SA_KEYFILE}" -n "${SA_NAMESPACE}"

	helm repo update

	helm get values ${SA_RELEASENAME} -n ${SA_NAMESPACE} >sampleapp-override"-$(date +%F)".yaml

	helm upgrade ${SA_RELEASENAME} ssp_helm_charts/ssp-sample-app -n ${SA_NAMESPACE} \
	 -f sampleapp-override"-$(date +%F)".yaml \
	--version=${sample_app_version} \
	--timeout '20m' --wait	
else

        print_color "red" "Sample App is not installed yet. Please install Sample App frist !!!"
        exit 1;
fi


print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Complete VIP Sample App Service Deloyment.. "
print_color "default" ""
print_color "green" "####################################################"
