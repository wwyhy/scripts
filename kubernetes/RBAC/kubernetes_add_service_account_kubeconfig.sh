#!/bin/bash
set -e
set -o pipefail

# https://gist.github.com/sdarwin/ffc5fed82b6128a7549fd6d5696d98a8
#
# Based on https://gist.github.com/innovia/fbba8259042f71db98ea8d4ad19bd708

# Add user to k8s using service account, no RBAC (must create RBAC after this script)
if [[ -z "$1" ]] || [[ -z "$2" ]]; then
 echo "usage: $0 <service_account_name> <namespace>"
 exit 1
fi

SERVICE_ACCOUNT_NAME=$1
NAMESPACE="$2"
KUBECFG_FILE_NAME="/tmp/kube/k8s-${SERVICE_ACCOUNT_NAME}-${NAMESPACE}-conf"
TARGET_FOLDER="/tmp/kube"

create_target_folder() {
    echo -n "Creating target directory to hold files in ${TARGET_FOLDER}..."
    mkdir -p "${TARGET_FOLDER}"
    printf "done"
}

create_service_account() {
    echo -e "\\nCreating a service account in ${NAMESPACE} namespace: ${SERVICE_ACCOUNT_NAME}"
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: ${SERVICE_ACCOUNT_NAME}
      namespace: ${NAMESPACE}
EOF
}

create_service_account_secret() {
    echo -e "\\nCreating a service account secret in ${NAMESPACE} namespace: ${SERVICE_ACCOUNT_NAME}-secret"
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: $SERVICE_ACCOUNT_NAME-secret
      namespace: ${NAMESPACE}
      annotations:
        kubernetes.io/service-account.name: $SERVICE_ACCOUNT_NAME
    type: kubernetes.io/service-account-token
EOF
}

get_secret_name_from_service_account_legacy() {
    echo -e "\\nGetting secret of service account ${SERVICE_ACCOUNT_NAME} on ${NAMESPACE}"
    SECRET_NAME=$(kubectl get sa "${SERVICE_ACCOUNT_NAME}" --namespace="${NAMESPACE}" -o json | jq -r .secrets[].name)
    echo "Secret name: ${SECRET_NAME}"
}

get_secret_name_from_service_account() {
    echo -e "\\nGetting secret of service account ${SERVICE_ACCOUNT_NAME} on ${NAMESPACE}"
    SECRET_NAME=${SERVICE_ACCOUNT_NAME}-secret
    echo "Secret name: ${SECRET_NAME}"
}

extract_ca_crt_from_secret() {
    echo -e -n "\\nExtracting ca.crt from secret..."
    kubectl get secret --namespace "${NAMESPACE}" "${SECRET_NAME}" -o json | jq \
    -r '.data["ca.crt"]' | base64 --decode > "${TARGET_FOLDER}/ca.crt"
    printf "done"
}

get_user_token_from_secret() {
    echo -e -n "\\nGetting user token from secret..."
    USER_TOKEN=$(kubectl get secret --namespace "${NAMESPACE}" "${SECRET_NAME}" -o json | jq -r '.data["token"]' | base64 --decode)
    printf "done"
}

set_kube_config_values() {
    context=$(kubectl config current-context)
    echo -e "\\nSetting current context to: $context"

    CLUSTER_NAME=$(kubectl config get-contexts "$context" | awk '{print $3}' | tail -n 1)
    echo "Cluster name: ${CLUSTER_NAME}"

    ENDPOINT=$(kubectl config view \
    -o jsonpath="{.clusters[?(@.name == \"${CLUSTER_NAME}\")].cluster.server}")
    echo "Endpoint: ${ENDPOINT}"

    # Set up the config
    echo -e "\\nPreparing k8s-${SERVICE_ACCOUNT_NAME}-${NAMESPACE}-conf"
    echo -n "Setting a cluster entry in kubeconfig..."
    kubectl config set-cluster "${CLUSTER_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --server="${ENDPOINT}" \
    --certificate-authority="${TARGET_FOLDER}/ca.crt" \
    --embed-certs=true

    echo -n "Setting token credentials entry in kubeconfig..."
    kubectl config set-credentials \
    "${SERVICE_ACCOUNT_NAME}-${NAMESPACE}-${CLUSTER_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --token="${USER_TOKEN}"

    echo -n "Setting a context entry in kubeconfig..."
    kubectl config set-context \
    "${SERVICE_ACCOUNT_NAME}-${NAMESPACE}-${CLUSTER_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}" \
    --cluster="${CLUSTER_NAME}" \
    --user="${SERVICE_ACCOUNT_NAME}-${NAMESPACE}-${CLUSTER_NAME}" \
    --namespace="${NAMESPACE}"

    echo -n "Setting the current-context in the kubeconfig file..."
    kubectl config use-context "${SERVICE_ACCOUNT_NAME}-${NAMESPACE}-${CLUSTER_NAME}" \
    --kubeconfig="${KUBECFG_FILE_NAME}"
}

create_rbac() {
    kubectl apply --namespace=$NAMESPACE -f - <<EOF
        kind: ClusterRoleBinding
        apiVersion: rbac.authorization.k8s.io/v1
        metadata:
          name: ${SERVICE_ACCOUNT_NAME}-clusterrolebinding
        subjects:
          - kind: ServiceAccount
            name: ${SERVICE_ACCOUNT_NAME}
            namespace: ${NAMESPACE}
        roleRef:
          kind: ClusterRole
          name: cluster-admin
          apiGroup: ""
EOF
}

create_target_folder
create_service_account
create_service_account_secret
get_secret_name_from_service_account
extract_ca_crt_from_secret
get_user_token_from_secret
set_kube_config_values
create_rbac

echo -e "\\nAll done! Test with:"
echo "KUBECONFIG=${KUBECFG_FILE_NAME} kubectl get pods"
KUBECONFIG=${KUBECFG_FILE_NAME} kubectl get pods
