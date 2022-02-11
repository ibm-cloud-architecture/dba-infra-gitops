# Digital Business Automation Infrastructure GitOps

This repository is defining different operands for Business Automation product. The operators are defined
in the catalog repository and the instances here are for deployment of components that will be used
to develop different automation solution.
As some of those solutions are using artifacts that are managed in the context of a product, then the 
governance of such artifacts stays within the product, and it is not recommended to adopt a gitops
approach for them. 
GitOps approach can still be used to manage common components, like BAStudio, ODM decision center,...

## Assumptions

We assume you have good understanding of GitOps practices and tools like OpenShift, OpenShift GitOps, [Kustomize](https://kustomize.io) 

## Specifications

* GitOps repositories should follow the structure prescribed by [Kubernetes Application Manager](https://github.com/redhat-developer/kam)

> KAM's goal is to help creating a GitOps project for an existing application as day 1 operations and then add more services as part of day 2 operation.

* GitOps repositories must contain an Argo CD "Application" resource for each of the Cloud Pak operators, 
which implies that at least the top-level Subscription object for an operator must reside in its own separate folder. 
* GitOps repositories must contain an Argo CD "Application" resource for each of the Cloud Pak capabilities.
* There are several situations where the order of synchronization of resources matters. For example, a 
Subscription resource references a CatalogSource. While the subscription can be applied to a cluster in the
 absence of the CatalogSource, the OLM operator will not process the subscription successfully until it can find 
 the catalog source. Outside of the already supported way to manage dependencies in GitOps, we can use  optional annotations in the resources
which will be used byt [ArgoCD synchronization phases and waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
* Each Cloud Pak is represented with an "App-of-Apps" Argo Application

## Things to address

Before adopting GitOps for production we need to address:

* Team ownership, where only authorized people can participate as authors, reviewers, and approvers in the git workflow.
he major Git infrastructure providers do not offer access control by folders inside repositories, so this kind of mapping tends to require different repositories.
* Environments, such as development, staging, and production. Many environment differences can be addressed with 
parameters in the resources. That is a preferred approach to reduce replication efforts across folders and minimize 
surprises with slight differences between environments creating blind spots in the progression of changes across 
the pipeline.
* Git Repository granularity: adoptingg the team based ownership may be a good approach. A mono repository for all Cloud Pak
may be a valuable solution for demonstration purpose.
* [Kustomize](https://kustomize.io) adoption: Using Kustomize allows the maintainer of a GitOps repository to selectively reference portions 
of other repositories, either in their literal form or with patched sections
* Helm dynamically generates the files based on functions and parameters, resulting in more reusable repositories, at the expense of 
some visibility into what is deployed on a target cluster
* Secret management approach: from pre-crating secrets in the cluster, use Sealed secrets, or use dynamic secret injection with Vault or [IBM Cloud Key Protect Services](https://www.ibm.com/cloud/key-protect)

## Scenarios

### Deploy BAW in a multitenant namespace 

The goal is to deploy the operators and operands for the dev, staging and production environments 
from the same central GitOps repository. The target deployment looks like in the following diagram:

![](./docs/images/BAW_BAI.png)
(src for this diagram: [docs/diagrams/Business_Automation_WorkflowOCP.drawio](https://github.com/ibm-cloud-architecture/dba-gitops-catalog/tree/main/docs/diagrams/BAW_BAI.drawio))

As an example, for the non-production OpenShift cluster, the `dba-dev` namespace, to deploy Business Automation Studio, the ArgoCD applications are:

![]()


## GitOps Bootstrap

* Login to the OpenShift Console, and get login token to be able to use `oc cli`
* Modify the `bootstrap.sh` script with your IAM user name
* Obtain your [IBM license entitlement key](https://github.com/IBM/cloudpak-gitops/blob/main/docs/install.md#obtain-an-entitlement-key) 
and save it in environment variable named IBM_ENTITLEMENT_KEY

    ```sh
    export IBM_ENTITLEMENT_KEY=...long-key...
    ```

* Start the bootstrap process to deploy the starter type in the `dba-dev` project. The operatos will be in the
`openshift-gitops` and monitor All Namespaces: 

  ```sh
    ./bootstrap.sh
  ```
  
  The previous operation will install the following operators into the `ibm-common-services` namespace:

  ![](./docs/imags/ics-operators.png)

  And the following operators to monitoring all namespaces. 

  ![](./docs/imags/OCPconsole-baoperators.png)

  Once the operators are running the command: `oc get pods -n openshift-gitops` should return
a list of pods like:

  ```sh
    NAME                                                          READY   STATUS    RESTARTS   AGE
    openshift-gitops-application-controller-0                     1/1     Running   0          4h5m
    openshift-gitops-applicationset-controller-6948bcf87c-jdv2x   1/1     Running   0          4h5m
    openshift-gitops-dex-server-64cbd8d7bd-76czz                  1/1     Running   0          4h5m
    openshift-gitops-redis-7867d74fb4-dssr2                       1/1     Running   0          4h5m
    openshift-gitops-repo-server-6dc777c845-gdjhr                 1/1     Running   0          4h5m
    openshift-gitops-server-7957cc47d9-cmxvw                      1/1     Running   0          4h5m
  ```


* Create an ArgoCD project to isolate the ArgoCD app for this deployment

    ```sh
    oc apply -k bootstrap/argocd-project 
    ```

* Get the ArgoCD `admin` user's password with the command

    ```sh
    oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
    ```

* Get the ArgoCD User Interface URL and open a web browser, use admin user and the previous password.

   ```sh
   chrome https://$(oc get route openshift-gitops-server -o jsonpath='{.status.ingress[].host}'  -n openshift-gitops)
   ```

* Deploy postgresql operator

   ```sh
    oc apply -k ./bootstrap/postgresql 
   ```

* Update the [OCP global pull secret of the `openshift-operators` project](https://github.com/IBM/cloudpak-gitops/blob/main/docs/install.md#update-the-ocp-global-pull-secret)
with the entitlement key, then create `ibm-entitlement-key` and `admin.registrykey`

    ```sh
    KEY=<yourentitlementkey>
    oc create secret docker-registry ibm-entitlement-key \
    --docker-username=cp \
    --docker-server=cp.icr.io \
    --namespace=openshift-operators \
    --docker-password=$KEY 
    # copy to admin.registrykey secreet
    oc project openshift-operators
    ./bootstrap/scripts/copySecrets.sh ibm-entitlement-key openshift-operators admin.registrykey
    ```

* To start the CD management with ArgoCD, just executing the following should work.

  ```sh
  oc apply -k config/argocd
  ```

 The expected set of ArgoCD apps looks like:

 ![](./docs/images/argocd-apps.png)

  and in the details for the 

 ![](./docs/images/argocd-baw-svc.png)

* Get the  `cp4ba-access-info` ConfigMaps for the different URLs to access the deployed capacities.

  ```sh
  oc describe cm icp4adeploy-cp4ba-access-info
  ```


## Add more environment

## Add more service 


## Contributions