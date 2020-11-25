## `hack/` 

This directory provides scripts for stopping and starting AKS cluster. 

### scripts 

1. Scale nodepools to 0 instance, and stop AKS cluster.
> `./stop-aks-cluster <resource-group> <cluster-name>`
2. Start AKS cluster, and scale nodepool to expected instances.
> `./start-aks-cluster <resource-group> <cluster-name>`
