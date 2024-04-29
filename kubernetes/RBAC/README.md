This script is used to create
  * namespace
  * service account
  * token
  * clusterrole
  * rolebinding
  * clusterrolebinding

and generate a kubeconfig to limit this config only has access to sepcify namespace.

Usage:
  * kubectl apply -f namespace_init.yaml
  * kubernetes_add_service_account_kubeconfig.sh <NAMESPACE> <SERVICE_ACCOUNT_NAME>
  
Note:
  * SERVICE_ACCOUNT_NAME is default to ns-sa-<NAMESPACE>
