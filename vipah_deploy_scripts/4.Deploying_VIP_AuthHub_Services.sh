#!/usr/bin/env bash

# Description: Deploy VIP AuthHub Service
# Created by: B.K. Rhim
# Last Modification: August 2023

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

ssp_version_old=$(helm list -n ${NAMESPACE} | grep infra-${RELEASENAME} | awk '{ print $10} ')
ssp_data_version_old=$(helm list -n ${NAMESPACE} | grep ${RELEASENAME}-data | awk '{ print $10} ')

while true
do

        print_color "default" "####################################################"
        print_color "default" ""
        print_color "red" "  Deploying VIP Auth Hub. Please select the version "
        print_color "default" ""
        print_color "green" "1. VIP Auth Hub $SSP_VERSION Install  (SSP build $SSP_VERSION_FULL)"
        print_color "blue" "2. Upgrade VIP Auth Hub to $SSP_VERSION (SSP build $SSP_VERSION_FULL)"
        print_color "default" ""
        print_color "default" "####################################################"
        print_color "default" "              Existing SSP Version : ${ssp_version_old}"
        print_color "default" "              Existing SSP Data Version : ${ssp_data_version_old}"
        print_color "default" "####################################################"
        print_color "default" ""
        print_color "default" ""
        read -p "Enter your choice: " choice

        case $choice in

                1) print_color "green" "VIP Auth Hub SSP $SSP_VERSION Install"
                        ssp_action="install"
                        ssp_version=$SSP_VERSION_FULL
                        ssp_data_version=$SSP_DATA_VERSION_FULL
                        break
                        ;; 
                2) print_color "green" "Upgrade VIP Auth Hub $SSP_VERSION Upgrade"
                        ssp_action="upgrade"
                        ssp_version=$SSP_VERSION_FULL
                        ssp_data_version=$SSP_DATA_VERSION_FULL
                        break
                        ;; 
                *) continue
                        ;; 
        esac
done

if [ "${ssp_action}" == "install" ] 
then

        if [[ ( $ssp_version < $ssp_version_old )  ]]; then
                print_color "red" " !!!!! ERROR: It is not allowed to downgrade SSP version with this scripts  !!!!!"
                exit 0
        fi

        kubectl create ns "${NAMESPACE}"
        helm repo add "${HELM_REPO}" "${HELM_REPO_URL}"
        helm repo update
        helm search repo "${HELM_REPO}" --versions

        print_color "default" ""
        print_color "red" "Install SSP Infa "
        print_color "default" ""

	kubectl create secret docker-registry ssp-infra-registrypullsecret -n ${NAMESPACE} \
	--docker-server="${SSP_DOCKER_SERVER}" \
	--docker-username="${SSP_USERNAME}" \
	--docker-password="${SSP_CREDENTIAL}" \
	--docker-email="${EMAIL_ADDRESS}"

# custom configuration for SSP logs

cat << EOF > customConfig_sspinfra.yaml
sspfbService:
  ingressLogsIncluded: false
fluent-bit:
  customConfig:
    outputs:
    - tags:
      - ssp_log
      - ssp_tp_log
      - ssp_audit
      template: | 
          Name es
          Host  elasticsearch-es-http.logging.svc
          Port  9200
          tls On
          tls.verify Off
          Suppress_Type_Name On
          Replace_Dots On
          Index \${tag}
          HTTP_User kibana
          HTTP_Passwd changeme
EOF

#        kubectl create secret tls ssp-general-tls --cert "${CERTFILE}" --key "${KEYFILE}" -n "${NAMESPACE}"

        # Check Node type check (docker or Containerd)
        Container_RunTime="$(kubectl get node -o wide | grep -i ready | awk '{print $13}'| head -n 1)"
        Container_Type1="containerd"
        Container_Type2="cri-o"
        if [[ ("$Container_RunTime" == *"$Container_Type1"*) || ("$Container_RunTime" == *"$Container_Type2"*) ]]; then
                # cntainerd or cri container                        
                print_color "default" "Node type is Containerd"
                

		helm install "infra-${RELEASENAME}" "${HELM_REPO}/ssp-infra" -n "${NAMESPACE}" \
		  --set sspReleaseName="${RELEASENAME}" \
		  --set db.enabled=true \
		  --set global.registry.existingSecrets[0].name='ssp-infra-registrypullsecret' \
		  --set fluent-bit.imagePullSecrets[0].name="ssp-infra-registrypullsecret" \
		  --set sspfbService.parser=cri \
		  --set fluent-bit.serviceAccount.create=true \
                  --set backend.es.host=elasticsearch-es-http.logging.svc \
                  --set backend.es.http_user=elastic \
                  --set backend.es.http_passwd="$(kubectl get secret -n logging elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d)" \
                  --set backend.es.tls="on" \
                  --set backend.es.tls_verify="off" \
		  -f customConfig_sspinfra.yaml \
		  --version=${ssp_version} \
                  --timeout '20m' \
		  --wait

        else
                # docker container
                print_color "default" "Node type is Containerd"

                print_color "Install VIP Auth Hub"
                
		helm install "infra-${RELEASENAME}" "${HELM_REPO}/ssp-infra" -n "${NAMESPACE}" \
                  --set sspReleaseName="${RELEASENAME}" \
                  --set db.enabled=true \
                  --set global.registry.existingSecrets[0].name='ssp-infra-registrypullsecret' \
		  --set fluent-bit.imagePullSecrets[0].name="ssp-infra-registrypullsecret" \
                  --set fluent-bit.serviceAccount.create=true \
                  --set backend.es.host=elasticsearch-es-http.logging.svc \
                  --set backend.es.http_user=elastic \
                  --set backend.es.http_passwd="$(kubectl get secret -n logging elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d)" \
                  --set backend.es.tls="on" \
                  --set backend.es.tls_verify="off" \
		  -f customConfig_sspinfra.yaml \
		  --version=${ssp_version} \
                  --timeout '20m' \
		  --wait

        fi

	# Wait for DB Creating when it uses embeded db

        print_color "default" ""
        print_color "red" "Waiting DB is completely created."
        print_color "default" ""

	kubectl wait jobs.batch \
	  --namespace "${NAMESPACE}" \
	  --selector "app.kubernetes.io/name=${RELEASENAME}-infra-create-db-job" \
	  --for 'condition=complete' \
	  --timeout '20m'
        

        print_color "default" ""
        print_color "red" "Install SSP"
        print_color "default" ""


	# Create secrete with ssp-registrypullsecret to install SSP
        kubectl delete secret ssp-registrypullsecret -n ${NAMESPACE}

        kubectl create secret docker-registry ssp-registrypullsecret -n ${NAMESPACE} \
        --docker-server="${SSP_DOCKER_SERVER}" \
        --docker-username="${SSP_USERNAME}" \
        --docker-password="${SSP_CREDENTIAL}" \
        --docker-email="${EMAIL_ADDRESS}"

	# Create TLS secret for ssp
	kubectl create secret tls ssp-general-tls --cert "${CERTFILE}" --key "${KEYFILE}" -n "${NAMESPACE}"

	# Deploy SSP with Demo mode. it limits the number of pod in SSP.. Otherwise, it deploys in produciton mode

	helm install "${RELEASENAME}" -n "${NAMESPACE}" "${HELM_REPO}/ssp" -f ./ssp-override.yaml \
	  --set ssp.ingress.host="${SSP_FQDN}" \
	  --set ssp.ingress.type="nginx" \
	  --set ssp.ingress.ingressClassName="nginx" \
	  --set ssp.ingress.tls.secretName=ssp-general-tls \
	  --set ssp.global.ssp.registry.existingSecrets[0].name=ssp-registrypullsecret \
	  --set hazelcast-enterprise.image.pullSecrets[0]=ssp-registrypullsecret \
	  --set hazelcast-enterprise.cluster.memberCount=1 \
          --version=${ssp_version} \
          --timeout '20m' \
	  --wait


        print_color "default" ""
        print_color "red" "Back Up MEK File into mek-secret_backup.yaml"
        print_color "default" ""

	kubectl get secret ${RELEASENAME}-${NAMESPACE}-keys-mek -n ${NAMESPACE} -o yaml >mek-secret_backup.yaml  

# Upgrade VIP Auth Hub (Infa and SSP)
elif [[ ( "${ssp_action}" == "upgrade" ) && ( ! -z "${ssp_version_old}" ) ]]
then

	print_color "default" ""

	print_color "red" "Upgrade DB CRD v1.12.0 !!! It is requred in Kubernetest 1.25"

        helm repo update

	kubectl apply -f https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/v1.18.0/deploy/crd.yaml	

	print_color "default" ""

        print_color "red" "Infra Upgrade"

	helm get values infra-${RELEASENAME} -n ${NAMESPACE} >infra-override"-$(date +%F)".yaml

	print_color "green" "Backup existing config map"

	kubectl get configmap ssp-infra-config -n ${NAMESPACE} -o yaml >fluent-bit-config"-$(date +%F)".yaml 

        if grep -q "customConfig:" ./infra-override"-$(date +%F)".yaml
        then
                echo "It is already updated. No need to change"
        else
                echo "update yaml file"

                sed -i '/fluent\-bit\:/a \
                customConfig:\
                outputs:\
                - tags:\
                - ssp_log\
                - ssp_tp_log\
                - ssp_audit\
                template: \|\
                        Name es\
                        Host  elasticsearch-es-http.logging.svc\
                        Port  9200\
                        tls On\
                        tls.verify Off\
                        Suppress_Type_Name On\
                        Replace_Dots On\
                        Index \$\{tag\}\
                        HTTP_User kibana\
                        HTTP_Passwd changeme
                ' ./infra-override"-$(date +%F)".yaml
        fi

	## Edit the infra-override.yaml file created in the previously to include the new customConfig configuration parameters under the fluent-bit section

	kubectl annotate configmap ssp-infra-config -n ${NAMESPACE} configVersion=1.0

	helm upgrade infra-${RELEASENAME} ${HELM_REPO}/ssp-infra -n ${NAMESPACE}  -f infra-override"-$(date +%F)".yaml \
        --set ssp.global.ssp.registry.credentials.username="${SSP_USERNAME}" \
        --set ssp.global.ssp.registry.credentials.password="${SSP_CREDENTIAL}" \
	--version=${ssp_version} \
	--timeout='20m' --wait


	print_color "red" "SSP Upgrade"

	# Delete docker registry and create it again.

	kubectl delete secret docker-registry ssp-infra-registrypullsecret -n ${NAMESPACE}

        kubectl create secret docker-registry ssp-infra-registrypullsecret -n ${NAMESPACE} \
        --docker-server="${SSP_DOCKER_SERVER}" \
        --docker-username="${SSP_USERNAME}" \
        --docker-password="${SSP_CREDENTIAL}" \
        --docker-email="${EMAIL_ADDRESS}"

	kubectl delete secret ssp-general-tls -n "${NAMESPACE}"

	kubectl create secret tls ssp-general-tls --cert "${CERTFILE}" --key "${KEYFILE}" -n "${NAMESPACE}"

	# Recreate secrete with ssp-registrypullsecret to upgrade SSP
        kubectl delete secret ssp-registrypullsecret -n ${NAMESPACE}

        kubectl create secret docker-registry ssp-registrypullsecret -n ${NAMESPACE} \
        --docker-server="${SSP_DOCKER_SERVER}" \
        --docker-username="${SSP_USERNAME}" \
        --docker-password="${SSP_CREDENTIAL}" \
        --docker-email="${EMAIL_ADDRESS}"

	# Backup user-supplifed deployment value 

	helm get values ${RELEASENAME} -n ${NAMESPACE} >ssp-override"-$(date +%F)".yaml 

	helm upgrade ${RELEASENAME} ${HELM_REPO}/ssp -n ${NAMESPACE}  -f ssp-override"-$(date +%F)".yaml \
	--version=${ssp_version} \
	--set ssp.featureFlags.dataseed.enabled=true \
	--timeout='20m' --wait 
	
else
        print_color "red" "SSP is not installed yet. Please install VIP Auth Hub frist !!!"
        exit 1;
fi

# Install SSP Data chart and load the data. It takes about 20 to 30 minutes.

if [[ ( "${ssp_action}" == "install" ) ]];
then
        print_color "default" ""
        print_color "red" "Install SSP-data Chart"
        print_color "default" ""
        
        print_color "green" "It takes about 20 -30 minues. You can go to the next step. ./5.Deploying_Sample_App.sh"

	helm install "${RELEASENAME}-data" -n "${NAMESPACE}" "${HELM_REPO}/ssp-data" \
	  --set sspReleaseName="${RELEASENAME}" \
	  --set ssp.global.ssp.registry.existingSecrets[0].name=ssp-registrypullsecret \
	  --version=${ssp_data_version} \
          --timeout '20m' \
	  --wait

elif [[ ( "${ssp_action}" == "upgrade" ) && ( ! -z "${ssp_data_version_old}" ) && ( ${ssp_data_version} > ${ssp_data_version_old} ) ]];
then

        print_color "default" ""
        print_color "red" "VIP Auth Hub Data Chart Upgrade!"
        print_color "default" ""

	helm upgrade --install  ${RELEASENAME}-data -n ${NAMESPACE} "${HELM_REPO}/ssp-data" \
	--set sspReleaseName=${RELEASENAME} \
	--set ssp.db.sslMode="REQUIRED" \
	--set ssp.global.ssp.registry.credentials.username="${SSP_USERNAME}" \
	--set ssp.global.ssp.registry.credentials.password="${SSP_CREDENTIAL}" \
	--version=${ssp_data_version} \
        --timeout '20m' \
        --wait

else

        print_color "default" "";
        print_color "red" "Invalidate option"
        print_color "default" ""
fi

print_color "green" "####################################################"
print_color "default" ""
print_color "red" "Complete VIP Auth Hub Deploy."
print_color "default" ""
print_color "green" "####################################################"

print_color "green" "####################################################"
print_color "default" ""
print_color "default" ""
print_color "default" ""
print_color "default" "VIP Auth Hub is ready. Please deploy Sample App. ./5.Deploying_Sample_App.sh "
print_color "default" ""
print_color "default" ""
print_color "green" "####################################################"