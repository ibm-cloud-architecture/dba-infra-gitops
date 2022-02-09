#!/usr/bin/env bash

# Set variables
if [[ -z ${IBM_ENTITLEMENT_KEY} ]]; then
  echo "Please provide environment variable IBM_ENTITLEMENT_KEY"
  exit 1
fi

IBM_ENTITLEMENT_KEY=${IBM_ENTITLEMENT_KEY}

SEALED_SECRET_NAMESPACE=${SEALED_SECRET_NAMESPACE:-sealed-secrets}
SEALED_SECRET_CONTOLLER_NAME=${SEALED_SECRET_CONTOLLER_NAME:-sealed-secrets-controller}
#SEALED_SECRET_CONTOLLER_NAME=$(oc get pods -n $SEALED_SECRET_NAMESPACE |  awk '{print $1}' | tail -n 1)

# Create Kubernetes Secret yaml
oc create secret docker-registry ibm-entitlement-key \
        --docker-username=cp \
        --docker-server=cp.icr.io \
        --namespace=openshift-operators --docker-password=${IBM_ENTITLEMENT_KEY} \
--dry-run=true -o yaml > delete-ibm-entitlement-key-secret.yaml

# Encrypt the secret using kubeseal and private key from the cluster
kubeseal -n ci --controller-name=${SEALED_SECRET_CONTOLLER_NAME} --controller-namespace=${SEALED_SECRET_NAMESPACE} -o yaml < delete-ibm-entitlement-key-secret.yaml > ibm-entitlement-key-sealed-secret.yaml

# NOTE, do not check delete-ibm-entitled-key-secret.yaml into git!
rm delete-ibm-entitlement-key-secret.yaml