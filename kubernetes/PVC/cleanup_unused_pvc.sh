#!/bin/bash

# Assume you have all config in one file.
cluster_list="cluster_A Cluster_B"

for cluster_name in $cluster_list; do
    kubectl config use-context $cluster_name
    kubens <namespace>
    
    # Get PVC list
    pvc_list=$(kubectl get pvc -o custom-columns=NAME:.metadata.name --no-headers)

    # Check if PVC is used by a pod by 'Used By'
    for pvc in $pvc_list; do
        used_by=$(kubectl describe pvc $pvc | awk '/Used By:/ {print $NF}')
        
        # It is safe to clean up if the 'Used By' is '<none>'
        if [ "$used_by" = "<none>" ]; then
            echo "Deleting PVC: $pvc"
            kubectl delete pvc $pvc
        else
            echo "Skipping PVC: The $pvc is Used By: $used_by"
        fi
    done
done
