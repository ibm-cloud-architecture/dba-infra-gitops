oc get catalogsource  ibm-operator-catalog -n openshift-marketplace
#echo $notfound
if [[ $? ]]
then
 echo "Define IBM catalog in openshift marketplace"
 oc apply -f https://raw.githubusercontent.com/ibm-cloud-architecture/dba-gitops-catalog/main/ibm-catalog/catalog_source.yaml
fi
