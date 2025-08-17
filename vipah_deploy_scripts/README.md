VIP Auth Hub Build Guide for Google Cloud Kubernetes Environment 

This guide will help you build VIP Auth Hub in your environment. 

Minimum version : Helm 3.3 above, Kubectl. 1.20 above. Please see VIP Auth Hub relase note (Jan 2022 release)

Install command line tools

# Install the Helm and Kubectl (root user)

    # Helm install (Version 3.7. Nov. 2021)
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

    # Helm version check
    helm version

    # Kubectl install (Version 1.22 Nov. 2021)

    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
    enabled=1
    gpgcheck=1
    repo_gpgcheck=1
    gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
    EOF

    yum install -y kubectl

    # kubectl version check
    kubectl version

# JQ install for token parsing -- Optional

    # It is used 6.Configure_ID_Store.sh execution
    # Install using yum

    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

    # Install jq:

    yum install -y jq

    # Verify:

    jq -Version


# Install LDAP Search command -- optional 

    # It is used to remove the phone numbers and email in LDAP server
    
    yum install -y openldap-clients


# Edit Environment variable setup (0.gks_env.sh)

First, you need to configure your environment variables. A template `config.sh.example` is provided.

1.  Copy the template to a new file named `config.sh`:
    ```bash
    cp vipah_deploy_scripts/config.sh.example vipah_deploy_scripts/config.sh
    ```
2.  Edit `vipah_deploy_scripts/config.sh` and provide your specific values for the environment variables.

    **IMPORTANT**: The `config.sh` file is ignored by git, so your secrets will not be committed.

# 0. Environment variable Export

    source ./0.gks_env.sh

    # Check the variable name such as SSP
    env

# 1. Create Google Kubernetes Cluster 

    # Please change kubernetes version if required
   
    ./1.create_gks_cluster.sh

    # Check Node in GCS

    kubectl get nodes

# 2. Deploy Ingress Controller

    ./2.Deploy_Ingress_Controller.sh

    # Please select Ingress Version.

    ####################################################

    Deploy Ingress Controller

    1. Ingress 4.0.16 deploy (VIP Auth Hub Jan 2022 on Kubernetes 1.22 above)
    2. Ingress 3.34.0 deploy (VIP Auth Hub Nov 2021 or Jan. 2022 on Kubernetes 1.21 below)
    3. Ingress 3.17.0 deploy (VIP Auth Hub July 2021)
    4. Upgrade Ingress 4.0.16 (VIP Auth Hub Nov 2021 on Kubernetes 1.22 above)
    5. Upgrade Ingress 3.34.0 (VIP Auth Hub Nov 2021 on Kubernetes 1.21 below)

    ####################################################
                Existing Ingress Version : xxxxxx
    ####################################################

    # check Ingress Service

    kubectl get svc -n ingress

# 3. Deploy Enclave Services (logging, monitoring, and tracing)

   ./3.Deploying_Enclave_Services.sh

    ####################################################

    Deploying Enclave Services

    1. Install elastic 7.16.2, jaeger 2.26.0, prometheus 31.0.0 (latest version)
    2. Install elastic 7.9.3, jaeger 2.14.2, prometheus 19.2.2 
    3. Upgrade elastic 7.16.2, jaeger 2.26.0, prometheus 19.2.2

    ####################################################

    # Check logging service (Elasticsearch)
    kubectl get pod -n logging

    # Check monitoring Service (Prometheus)
    kubectl get pod -n monitoring

    # Check tracing service (Jaeger)
    kubectl get pod -n tracing

    # Add Host Name and IP Address in host file or DNS server. Please also update hosts file where you execute kubectl commands

# 4. Deploy VIP Auth Hub Service

    ./4.Deploying_VIP_AuthHub_Services.sh

    # Please select the correct version. (install or upgrade) 

    ####################################################

    Deploying VIP Auth Hub. Please select the version

    1. VIP Auth Hub SSP Apr. 2022 release (SSP build 1.0.2940)
    2. VIP Auth Hub SSP Jan. 2022 release (SSP build 1.0.2810)
    3. Upgrade VIP Auth Hub to Apr. 2022 release (SSP build 1.0.2940)
    4. Upgrade VIP Auth Hub to Jan. 2022 release (SSP build 1.0.2810)

    ####################################################
                Existing SSP Version : xxxxx
                Existing SSP Data Version : xxxxx
    ###################################################

# 5. Deploy Sample Service

    ./5.Deploying_Sample_App.sh

    # Please select the sample app version. It should be the same version in VIP Auth Hub Service.

    ####################################################

    Deploying VIP Auth Hub Sample App. Please select the version

    1. Install VIP Auth Hub Sample App Apr. 2022 release (Sample App build 1.0.2940)
    2. Install VIP Auth Hub Sample App Jan. 2021 release (Sample App build 1.0.2810)
    3. Upgrade VIP Auth Hub Sample App Apr. 2022 release (Sample App build 1.0.2940)
    4. Upgrade VIP Auth Hub Sample App Jan. 2021 release (Sample App build 1.0.2810)

    ####################################################
    ####################################################
    Existing Sample App version: ssp-sample-app-xxxxxx
    ####################################################

# 6. ID Store (LDAP) Set Up from command line (optional)

    # Please do a network connection check where you execute the commands. ex: ping app01.security.demo-broadcom.com. When it cannot connect app[suffx].security.demo-broadcom.com. Step 6 will not work properly.
    # Update CORS Setting, Register LDAP, and Add Admin LDAP Group as VIP Auth Hub Admin Group

    ./6.Configure_ID_Store.sh

    # Access Sample App and validate the login with nbruce/password, ex: https://<SA_FQDN>/sample-app/

# 7.Remove mobile phone number in the Sample User Directory (optional)

    ./7.Remove_Mobile_Number.sh

# 9. Delete Sample App and VIP Auth Hub

    # It deleted Sample App and VIP Auth Hub. It does not change the FQDN or IP Address.

    ./9.delete_sample_app_and_ssp.sh

# 99. Delete Services (Sample App, VIP Auth Hub, Monitoring, Logging, Tracing and Ingress)

    # Remove entire service in the cluster. When install VIP Auth Hub again, it will have different Ingress Address. 

    ./99.delete_ssp.sh

# 999. Delete Google Kubernete Cluster

    # Remove the clsuter. If you do not want to use the service, please delete the cluster accordingly.
    
    ./999.gks_cluster_delete.sh
