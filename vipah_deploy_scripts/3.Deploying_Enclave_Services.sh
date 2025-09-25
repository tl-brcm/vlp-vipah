#!/usr/bin/env bash

# Description: Deploy Enclave Service (Monitoring and Auditing)
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

while true
do
        ingress_version_old=$(helm list -n ingress | grep ingress | awk '{ print $9} ')

        print_color "default" "####################################################"
        print_color "default" ""
        print_color "red"  " Deploying Enclave Services "
        print_color "default" ""
        print_color "green" "1. Install elastic operator 3.0.0, Elastic 9.0.4, Kibana 9.0.4, Prometheuse 11.2.16 "
        print_color "green" "2. Upgrade elastic operator 3.0.0, Elastic 9.0.4, Kibana 9.0.4, Prometheuse 11.2.16 "
        print_color "default" ""
        print_color "default" "####################################################"
        print_color "default" ""
        read -p "Enter your choice: " choice

        case $choice in

                1) print_color "green" "Install elastic operator 3.0.0, Elastic 8.2.1, Kibana 8.2.0, Prometheuse 8.1."
                        enclave_service_version="latest"
			elastic_operator_version="3.0.0"
			elastic_search_version="9.0.4"
			kibana_version="9.0.4"
			prometheus_operator_version="8.25.6"
			grafana_operator_version="3.7.1"
			grafana_image_tag_version="10.3.1-debian-11-r0"
                        break
                        ;; 
                2) print_color "green" "Upgrade elastic operator 3.0.0, Elastic 8.2.1, Kibana 8.2.0, Prometheuse 8.1."
                        enclave_service_version="upgrade"
			elastic_operator_version="3.0.0"
                        break
                        ;; 
                *) continue
                        ;; 
        esac
done

#####################
# Deploying Elastic Search and Kibana for logging
#####################

# Create logging Namespace

if [ "$enclave_service_version" != "upgrade" ]
then
        kubectl create ns logging
fi

helm repo add elastic https://helm.elastic.co
helm repo update

kubectl create secret docker-registry docker-hub-registrypullsecret -n logging \
--docker-server="https://index.docker.io/v2/" \
--docker-username=${DOCKER_USERNAME} \
--docker-password=${DOCKER_PASSWORD} \
--docker-email=${DOCKER_EMAIL}


print_color "default" ""
print_color "green" "Deploy Elastic Search Operator"
print_color "default" ""

# Deploy ECK operator globally

helm install elastic-operator elastic/eck-operator -n logging \
--set imagePullSecrets[0].name="docker-hub-registrypullsecret" \
--version=${elastic_operator_version}

# Create Elastic Admin User using secret
 
kubectl create secret generic kibana-user  -n logging \
--from-literal roles=superuser \
--from-literal username=kibana \
--from-literal password=changeme

# Elastic Search 9.0.4 creation
#

cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch
  labels:
    app: elasticsearch-master
  namespace: logging
spec:
  version: ${elastic_search_version}
  #image: private.registry.io/elasticsearch/elasticsearch: 9.0.4
  http:
    service:
      metadata:
  nodeSets:
    - config:
        node.roles:
          - master
          - data
        node.store.allow_mmap: false
      podTemplate:
        metadata:
          labels:
            app: elasticsearch-master
        spec:
          #imagePullSecrets:
          #- name: <registry-secret-name>
          containers:
          - name: elasticsearch
            resources:
              requests:
                memory: 4Gi
                cpu: 1
              limits:
                memory: 4Gi
                cpu: 1
      volumeClaimTemplates:
      - metadata:
          name: elasticsearch-data
        spec:
          #storageClassName: fast
          accessModes:
          - ReadWriteOnce
          resources:
            requests:
              storage: 50Gi
      name: default
      count: 1
  volumeClaimDeletePolicy: DeleteOnScaledownOnly
  auth:
    fileRealm:
     #To create new elastic users, see: https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-users-and-roles.html
    - secretName: kibana-user ##uncomment if you want to create users/set password in elastic. 
EOF

# end of Elastic Search 9.0.4 yaml

# Cechk PCV for logging


print_color "green" "Wait for pod to be Running Status"

while [[ $(kubectl get pods -l app=elasticsearch-master -n logging -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
   sleep 10
done

kubectl get pvc -n logging

print_color "default" ""
print_color "green" "Deploy Kibana Service ver.9.0.4"
print_color "default" ""

# Deploy Kibana Secret

kubectl delete secret logging-general-tls -n logging

kubectl create secret tls logging-general-tls \
--cert "${CERTFILE}" \
--key "${KEYFILE}" -n logging

# Kibana Yaml start
#kubectl apply -f Kibana_V8.2.0.yaml

cat <<EOF | kubectl apply -n logging -f - 
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: logging
spec:
  version: ${kibana_version}
  #image: private.registry.io/elasticsearch/elasticsearch: 8.2.0
  elasticsearchRef:
    name: elasticsearch
    namespace: logging
    serviceName: elasticsearch-es-http
  http:
    service:
      spec:
        type: ClusterIP
    tls:
      selfSignedCertificate:
        subjectAltNames:
        - dns: ${KIBANA_HOST}
  podTemplate:
    metadata:
      labels:
        app: kibana
    spec:
      #imagePullSecrets:
      #- name: <registry-secret-name>   
      containers:
        - name: kibana
          resources:
            requests:
              memory: 1Gi
              cpu: 0.5
            limits:
              memory: 2Gi
              cpu: 1
  count: 1
EOF


# end of Kibana Yaml


print_color "green" "Wait for kibana pod to be Running Status"

while [[ $(kubectl get pods -l app=kibana -n logging -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
   sleep 10
done

kubectl get pod -n logging

# Expose Kibana Service

print_color "green" "Export Kibana Service"

# Kibana service expose yaml start

cat <<EOF | kubectl apply -n logging -f - 
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kibana
  namespace: logging
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "https"
spec:
  ingressClassName: nginx
  rules:
    - host: ${KIBANA_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kibana-kb-http
                port:
                  number: 5601
  tls:
    - hosts:
      - ${KIBANA_HOST}
      secretName: logging-general-tls
EOF

# end of Kibana service expose

print_color "default" ""
print_color "green" "Deploying Prometheus and Grafana for Metric"
print_color "default" ""

######################
# Deploying Prometheus and Grafana for Metrics
######################

# Create Namepace for monitoring
if [ "$enclave_service_version" != "upgrade" ]
then
        kubectl create ns monitoring
fi

# Load the bitnami chart repository

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

kubectl create secret docker-registry docker-hub-registrypullsecret -n monitoring \
--docker-server="https://index.docker.io/v2/" \
--docker-username=${DOCKER_USERNAME} \
--docker-password=${DOCKER_PASSWORD} \
--docker-email=${DOCKER_EMAIL}

# Deploy Prometheus under monitoring namespace
# Create TLS for laert manager

kubectl create secret tls ${ALERTMANAGER_HOST}-tls --cert ${CERTFILE} --key ${KEYFILE} -n monitoring

# Deploy Prometheus-operator
helm install prometheus-operator bitnami/kube-prometheus -n monitoring \
--set alertmanager.ingress.enabled=true \
--set alertmanager.ingress.ingressClassName=nginx \
--set alertmanager.ingress.hostname=${ALERTMANAGER_HOST} \
--set prometheus.persistence.enabled=true \
--set alertmanager.persistence.enabled=true \
--set alertmanager.ingress.tls=true \
--set global.imagePullSecrets[0].name=${docker-hub-registrypullsecret} \
--set grafana.image.pullSecrets[0]=${docker-hub-registrypullsecret} \
--version=${prometheus_operator_version} \
--timeout='20m' --wait

# Verfify

kubectl get pvc -n monitoring

print_color "green" "Wait for alertmanager pod is ready"

while [[ $(kubectl get pods -l alertmanager=prometheus-operator-kube-p-alertmanager -n monitoring -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
   sleep 10
done

kubectl get pods -n monitoring


# Deploy Grafana
# Create tls secret for SSL

kubectl delete secret monitoring-general-tls  -n monitoring

kubectl create secret tls monitoring-general-tls \
--cert "${CERTFILE}" \
--key "${KEYFILE}" -n monitoring

helm install grafana-operator bitnami/grafana-operator -n monitoring \
--set  operator.containerSecurityContext.readOnlyRootFilesystem=true \
--set grafana.image.repository=bitnami/grafana \
--set grafana.config.security.admin_password=prom-operator \
--set grafana.ingress.enabled=true \
--set grafana.ingress.ingressClassName=nginx \
--set grafana.ingress.hostname=${GRAFANA_HOST} \
--set grafana.ingress.tls=true \
--set grafana.ingress.tlsSecret=monitoring-general-tls \
--set grafana.image.tag=${grafana_image_tag_version} \
--version=${grafana_operator_version} \
--timeout='20m' --wait
# Configure Grafana to use the local Prometheus by creating a Grafana DataSource Object

cat <<EOF | kubectl apply -n monitoring -f - 
  apiVersion: grafana.integreatly.org/v1beta1
  kind: GrafanaDatasource
  metadata:
    name: grafana-datasource
    namespace: monitoring
  spec:
    # Tell the operator which Grafana instance should own this datasource
    instanceSelector:
      matchLabels:
        dashboards: "ssp-grafana"
    datasource:
      name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus-operator-kube-p-prometheus.monitoring.svc:9090
      isDefault: true
      editable: true
      jsonData:
        timeInterval: 5s
EOF

cat <<EOF | kubectl apply -n monitoring -f -
 apiVersion: grafana.integreatly.org/v1beta1
 kind: GrafanaDashboard
 metadata:
   name: ssp-monitoring-dashboard
 spec:
   datasources:
     - inputName: "DS_PROMETHEUS"
       datasourceName: "Prometheus"
   instanceSelector:
     matchLabels:
       dashboards: "ssp-grafana"
   grafanaCom:
     id: 20026
EOF

# Delete the existing Grafana Pod so that the monitoring namepsace configuration is read in

kubectl delete pod -l app.kubernetes.io/name=grafana-operator -n monitoring

print_color "default" ""
print_color "green" "Check the Service and Extract IP address"
print_color "default" ""

# Get Node

kubectl get nodes -o wide

# Get Pod in monitoring namesapce

kubectl get pod -n monitoring

print_color "green" "Get Ingress Service Information"

kubectl get svc -n ingress ingress-nginx-controller

# GCS
IPADDRESS=$(kubectl get svc -n ingress ingress-nginx-controller | awk '{ print $4 }' | sed -n 2p )

# AWS 
#IPADDRESS=$(kubectl get svc -n ingress |grep LoadBalancer | awk '{ print $4 }' | nslookup | grep -i 'Address:' | sed -n 2p | awk '{ print $2 }')


print_color "green" "####################################################"
print_color "default" ""
print_color "green" "Update hosts file or DNS Server"
print_color "blue" "sudo echo \"${IPADDRESS}       ${KIBANA_HOST}  ${JAEGER_HOST}  ${ALERTMANAGER_HOST}  ${GRAFANA_HOST} ${SSP_FQDN}   ${SA_FQDN}\" >> /etc/hosts"
echo "${IPADDRESS}       ${KIBANA_HOST}  ${JAEGER_HOST}  ${ALERTMANAGER_HOST}  ${GRAFANA_HOST} ${SSP_FQDN}   ${SA_FQDN}" > suggested_dns_changes.txt
print_color "red" "Complete deploying Enclave Services.. Please check the configurations."

print_color "default" ""
print_color "green" "####################################################"