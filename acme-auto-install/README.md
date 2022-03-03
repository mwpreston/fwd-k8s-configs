# Installer for Acme Fitness

## Description
This repository contains an installer script `install.sh` and yaml files required to install the Acme Fitness application into Kubernetes

## Notes
Some of the yaml files have been modified in order to support my preferred installation
* catalog-db-total.yaml - This file has been modified in order to support using a Persistent Volume for the mongo database. It currenlty mounts the db data into a PeristentVolume. The subsequent PersistentVolumeClaim utilizes the rook-ceph-block storage class and is mounted with ReadWriteOnce

## Usage
Clone the repository to a location where it is accessable

Run `install.sh` and answer the following prompts
* namespace: The desired namespace to install the appliation in
* secrets: The value that should be used for the secrets created

That's all!  Your good!  A quick `kubectl get svc` should show you the NodePort utilized for the frontend service. 

