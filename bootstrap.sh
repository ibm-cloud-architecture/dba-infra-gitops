SCRIPT_VERSION=3.2.3
CP_VERSION=21.0.3

export CP4BA_AUTO_CLUSTER_USER="IAM#boyerje@us.ibm.com"

# modify with care
export ENTITLEMENT_KEY=`cat ./assets/entitlement_key.text`
export IBM_EMAIL=`cat ./assets/entitlement_key.text`

if [[ -z "$IBM_ENTITLEMENT_KEY" ]]; then
      echo "Need IBM_ENTITLEMENT_KEY key set"
      exit 1
fi

# Environment variables used by the silent mode of the cp4a-clusteradmin-setup.sh script
export CP4BA_AUTO_PLATFORM="ROKS"
export CP4BA_AUTO_ALL_NAMESPACES=Yes
export CP4BA_AUTO_DEPLOYMENT_TYPE="starter"
export CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS="ibmc-file-gold-gid"
export CP4BA_AUTO_ENTITLEMENT_KEY=$IBM_ENTITLEMENT_KEY
export CP4BA_AUTO_NAMESPACE=dba-dev

echo "##### 1- create user $CP4BA_AUTO_CLUSTER_USER"
htpasswd -c -B -b users.htpasswd $CP4BA_AUTO_CLUSTER_USER $CP4BA_AUTO_CLUSTER_USER
oc create secret generic htpass-secret --from-file=htpasswd=./users.htpasswd -n openshift-config
oc apply -f bootstrap/identityProvider.yaml
oc adm policy add-cluster-role-to-user cluster-admin $CP4BA_AUTO_CLUSTER_USER


echo "##### 2- Define GitOps operators"
./bootstrap/scripts/installGitOpsOperators.sh
oc apply -k bootstrap/sealed-secrets
oc apply -k bootstrap/postgresql

echo "##### 3- Get IBM CP automation configuration and scripts"
source ./bootstrap/scripts/getCpAutomationSDK.sh
getCpAutomationSDG ${SCRIPT_VERSION} ${CP_VERSION}

sed -i '' 's/<NAMESPACE>/'"${CP4BA_AUTO_NAMESPACE}"'/' ./assets/ibm-cp-automation/inventory/cp4aOperatorSdk/files/deploy/crs/cert-kubernetes/descriptors/cluster_role_binding.yaml

echo "##### 4- Create OCP project named: ${CP4BA_AUTO_NAMESPACE}"
oc new-project ${CP4BA_AUTO_NAMESPACE}
oc project ${CP4BA_AUTO_NAMESPACE}

oc apply -f bootstrap/ibm-cp4a-operator/service-account.yaml -n ${CP4BA_AUTO_NAMESPACE}
#oc adm policy add-scc-to-user privileged -z ibm-cp4ba-privileged -n ${CP4BA_AUTO_NAMESPACE}
oc adm policy add-scc-to-user anyuid -z ibm-cp4ba-anyuid -n ${CP4BA_AUTO_NAMESPACE}

cd ./assets/ibm-cp-automation/inventory/cp4aOperatorSdk/files/deploy/crs/cert-kubernetes/scripts
./cp4a-clusteradmin-setup.sh
cd "$OLDPWD"
