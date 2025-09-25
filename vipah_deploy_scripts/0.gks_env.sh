#!/usr/bin/env bash

# Description: Deploy VIP AuthHub Service
# Created by: B.K. Rhim
# Modified by: Tony Liang
# Last Modification: Feb. 27, 2024

DIRNAME="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"

# Source the configuration file
if [ -f "${DIRNAME}/config.sh" ]; then
  source "${DIRNAME}/config.sh"
else
  echo "Error: config.sh not found. Please copy config.sh.example to config.sh and fill in your values."
  exit 1
fi

# server.key : SSL Private key, server_add_chain.crt: SSL public cert and Chain Certificate
# SSL certificate is wilde certificate.. demo-broadcom.com

# Suffix is used for Host name + SUFFIX, for example, kibana01.demo-broadcom.com, grafana01.demo-broadcom.com
export SUFFIX="-215"

export PREFIX="ssp"
export RELEASENAME="ssp"
export NAMESPACE="ssp"
export CERTFILE="${DIRNAME}/server_add_chain.crt"
export KEYFILE="${DIRNAME}/server.key"
export DOMAIN="demo-broadcom.com"
export FIDO_DOMAIN="demo-broadcom.com"      # Due to SSP19 limitation, it should use last 2 domain
export SSP_FQDN="ssp${SUFFIX}.${DOMAIN}"    # ex: ssp01.security.demo-broadcom.com

export APP_NAME_SPACE="sample-app"
export SAMPLE_APP_RELEASE_NAME="sample-app"
export APP_FQDN="app${SUFFIX}.${DOMAIN}"    #ex: app01.security.demo-broadcom.com

# HELM REPOSITORY FOR SSP
export HELM_REPO="ssp_helm_charts"
export HELM_REPO_URL="https://ssp_helm_charts.storage.googleapis.com"

export SA_NAMESPACE="sample-app"
export SA_RELEASENAME="sample-app"
export SSP_URL="https://${SSP_FQDN}/default/"
export SA_FQDN="${APP_FQDN}"

export SA_KEYFILE="${DIRNAME}/server.key"
export SA_CERTFILE="${DIRNAME}/server_add_chain.crt"

# Cluster Name in GCS ..
export GCS_CLUSTER_NAME="ssp-215"

# Logging Monitoring Host

export KIBANA_HOST="kibana${SUFFIX}.${DOMAIN}"
export JAEGER_HOST="jaeger${SUFFIX}.${DOMAIN}"
export ALERTMANAGER_HOST="alertmanager${SUFFIX}.${DOMAIN}"
export GRAFANA_HOST="grafana${SUFFIX}.${DOMAIN}"

export DOCKER_USERNAME="bkrhim1004"

export SSP_DOCKER_SERVER="https://securityservices.packages.broadcom.com/"

export SSP_VERSION=3.4.2
export SSP_VERSION_FULL="$SSP_VERSION+1051"
export SSP_DATA_VERSION_FULL="2025.29"

# Dev branch
# export SSP_VERSION=3.5.0
# export SSP_VERSION_FULL="$SSP_VERSION-1095.dev"
# export SSP_DATA_VERSION_FULL="2025.24"
