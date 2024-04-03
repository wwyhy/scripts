#!/bin/bash
set -x

#Conculate the resource details for all namespaces  
echo "namespace,pod,container,request_cpu,limit_cpu,usage_cpu,request_mem,limit_mem,usage_mem" >> resource-result.csv

for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
#for ns in $(kubectl get ns |grep cats | awk '{print $1}'); do
    for pod in $(kubectl get pod -n $ns |grep Running|awk '{print $1}'); do
        for container in $(kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[*].name}'); do
            req_cpu=$(kubectl get pod $pod -n $ns -o jsonpath="{.spec.containers[?(@.name=='$container')].resources.requests.cpu}")
            req_mem=$(kubectl get pod $pod -n $ns -o jsonpath="{.spec.containers[?(@.name=='$container')].resources.requests.memory}")
            lim_cpu=$(kubectl get pod $pod -n $ns -o jsonpath="{.spec.containers[?(@.name=='$container')].resources.limits.cpu}")
            lim_mem=$(kubectl get pod $pod -n $ns -o jsonpath="{.spec.containers[?(@.name=='$container')].resources.limits.memory}")
            usage_cpu=$(kubectl top pod $pod -n $ns --containers=true --no-headers | awk '{print $3}' | awk '{s+=$1} END {print s}')
            usage_mem=$(kubectl top pod $pod -n $ns --containers=true --no-headers | awk '{print $4}' | awk '{s+=$1} END {print s}')
            if [[ "$req_cpu" != "" && "$req_mem" != "" && "$lim_cpu" != "" && "$lim_mem" != "" ]]; then
                echo "$ns,pod,container,req_cpu,lim_cpu,usage_cpu,req_mem,lim_mem,usage_mem" >> resource-result.csv
            fi
        done
    done
done
