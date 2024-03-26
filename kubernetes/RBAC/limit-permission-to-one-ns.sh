#!/bin/bash

# Set namespace and cluster details
NAMESPACE=$1
CLUSTER_NAME=xxx-k8s
SERVER_URL=https://xxxxx:8081

if [[ -z "$NAMESPACE" ]]; then
        echo "Use "$(basename "$0")" NAMESPACE";
        exit 1;
fi

# Create namespace
if [ ! -d ./$NAMESPACE ]; then
    mkdir ./$NAMESPACE
fi

cat > ./$NAMESPACE/sa.yaml<<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  labels:   
    app: $NAMESPACE
    toolkit.fluxcd.io/tenant: $NAMESPACE
  name: $NAMESPACE
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    toolkit.fluxcd.io/tenant: $NAMESPACE
  name: ns-sa-admin-$NAMESPACE
  namespace: $NAMESPACE
EOF

kubectl apply -f $NAMESPACE/sa.yaml

# Generate a token associated with the service account
#SECRET_NAME=$(kubectl get sa ns-sa-admin-$NAMESPACE -n $NAMESPACE -o jsonpath='{.secrets[0].name}')
#TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)
TOKEN=$(kubectl -n $NAMESPACE create token ns-sa-admin-$NAMESPACE --duration=87600h)

# Create Role and RoleBinding
cat > ./$NAMESPACE/clusterrole.yaml <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $NAMESPACE
  name: ns-sa-admin-$NAMESPACE
rules:
- apiGroups: ["", 'extensions', 'apps']
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ['batch']
  resources:
  - jobs
  - cronjobs
  verbs: ['*']
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    toolkit.fluxcd.io/tenant: $NAMESPACE
  name: ns-sa-admin-$NAMESPACE
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: ns-sa-admin-$NAMESPACE
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: ns-sa-admin-$NAMESPACE
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f ./$NAMESPACE/clusterrole.yaml

# Generate kubeconfig file
cat <<EOF > ./$NAMESPACE/config
apiVersion: v1
kind: Config
clusters:
- name: $CLUSTER_NAME
  cluster:
    certificate-authority-data: <base64-ca-crt>
    server: $SERVER_URL
contexts:
- name: ns-sa-admin-$NAMESPACE
  context:
    cluster: $CLUSTER_NAME
    user: ns-sa-admin-$NAMESPACE
    namespace: $NAMESPACE
current-context: ns-sa-admin-$NAMESPACE
users:
- name: ns-sa-admin-$NAMESPACE
  user:
    token: $TOKEN
EOF
