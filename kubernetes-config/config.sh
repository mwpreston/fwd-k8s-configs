# Kubeadm Configuration
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Untaint Master Node (replace hostname with whatever we end up calling it)
kubectl taint node mp-k8s-test node-role.kubernetes.io/master:NoSchedule-

# Install Flannel CNI
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

# Get Repo for rest of config
cd $HOME
git clone https://github.com/mwpreston/fwd-k8s-configs.git

# Install Volume Snapshot CRDS
kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/v1betacrd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/v1betacrd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/v1betacrd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml 

kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/snapcontroller/rbac-snapshot-controller.yaml
kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/snapcontroller/setup-snapshot-controller.yaml

kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/v1crd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/v1crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/v1crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml

# need to install host path

/home/admin/fwd-k8s-configs/kubernetes-config/hostpathcsi/deploy/kubernetes-1.21/deploy.sh

kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/hostpathcsi/examples/csi-storageclass.yaml

kubectl apply -f /home/admin/fwd-k8s-configs/kubernetes-config/hostpathcsi/deploy/kubernetes-1.21/hostpath/csi-hostpath-snapshotclass.yaml
