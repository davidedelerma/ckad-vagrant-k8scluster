#!/bin/bash
#
# Setup for Node servers

set -euxo pipefail

CONTROL_IP="10.0.0.10"
MAX_ATTEMPTS=30
WAIT=10
config_path="/vagrant/configs"

echo "[INFO] Waiting for controlplane at $CONTROL_IP:6443..."

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  if nc -z "$CONTROL_IP" 6443; then
    echo "[INFO] Controlplane is reachable!"
    break
  fi
  echo "[WARN] Attempt $i: controlplane not ready, retrying in $WAIT seconds..."
  sleep "$WAIT"
done

# Now join the cluster
/bin/bash "$config_path/join.sh" -v

# Setup kubeconfig for vagrant user and label the node
sudo -i -u vagrant bash << 'EOF'
whoami
mkdir -p /home/vagrant/.kube
cp -i /vagrant/configs/config /home/vagrant/.kube/config
chown 1000:1000 /home/vagrant/.kube/config
kubectl label node "$(hostname -s)" node-role.kubernetes.io/worker=worker
EOF
