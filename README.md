# 🧰 Vagrant-Based Kubernetes Cluster on Fedora (Using libvirt)

This project provisions a local multi-node Kubernetes cluster using:

- **Fedora** as the host OS
- **Vagrant + libvirt** for virtualization
- `kubeadm` for cluster bootstrapping
- Calico for networking
- Kubernetes Dashboard + Metrics Server for observability

---

## 🖥️ Requirements (Fedora)

### ✅ System Requirements

- Fedora Linux (tested on Fedora 39+)
- CPU with virtualization support (Intel VT-x / AMD-V)
- At least 6 GB RAM, 3 CPU cores free

### 📦 Install Required Packages

```bash
sudo dnf install -y @virtualization vagrant libvirt qemu-kvm \
  virt-manager libvirt-devel gcc ruby-devel make
```

### 🔌 Enable and Start libvirt

```bash
sudo systemctl enable --now libvirtd
```

### 👤 Add Your User to libvirt Group

```bash
sudo usermod -aG libvirt $(whoami)
```

> You must log out and log back in (or reboot) after this step.

---

## ✅ Check libvirt Setup

```bash
virsh list --all
```

If this command runs without error, your libvirt setup is functional.

You can also verify that the libvirt daemon is running:

```bash
systemctl status libvirtd
```

---

## 📂 Cluster Overview

| VM Name       | Role        | CPU | RAM   | Private IP   |
|---------------|-------------|-----|-------|--------------|
| controlplane  | Master Node | 2   | 2048M | 10.0.0.10    |
| node01        | Worker Node | 1   | 1536M | 10.0.0.11    |
| node02        | Worker Node | 1   | 1536M | 10.0.0.12    |

---

## 🚀 Launch the Cluster

```bash
git clone <your-repo-url>
cd <your-repo-dir>
vagrant up --provider=libvirt
```

> ⏱️ Initial setup may take several minutes.

---

## 🛑 Stop or Destroy the Cluster

- To shut down the VMs:

```bash
vagrant halt
```

- To remove everything:

```bash
vagrant destroy -f
```

---

## ⚙️ Using kubectl

### Set kubeconfig

```bash
export KUBECONFIG=$(pwd)/configs/config
```

### Test

```bash
kubectl get nodes
```

You should see the control plane and worker nodes all in `Ready` state.

---

## 📊 Kubernetes Dashboard

### Start the Dashboard Proxy

```bash
kubectl proxy
```

### Open Dashboard in Browser

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### Get Login Token

```bash
kubectl -n kubernetes-dashboard describe secret \
  $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
```

Copy and paste the token into the login page.

---

## 🧪 Deploy an Example App

### 1. Create Pod YAML (basicpod.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: basicpod
spec:
  containers:
  - name: webcont
    image: nginx
    ports:
    - containerPort: 80
```

```bash
kubectl apply -f basicpod.yaml
```

### 2. Expose with NodePort (basicservice.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: basicservice
spec:
  selector:
    name: basicpod
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

```bash
kubectl apply -f basicservice.yaml
```

---

## 🌐 Access the NGINX App

You have **two options**:

### 🔍 Option 1: Use Node IP Address

Get the internal IP of a worker node:

```bash
kubectl get nodes -o wide
```

Use the IP of a node (e.g., `10.0.0.11`) and the `nodePort` (e.g., `30080`):

```bash
curl http://10.0.0.11:30080
```

> You must run this from the host Fedora machine that can reach the VM network.

---

### 🔁 Option 2: Forward the Port via Vagrantfile

Modify your `Vagrantfile` to add a forwarded port from host to node (example for `node01`):

```ruby
config.vm.define "node01" do |node|
  node.vm.network "forwarded_port", guest: 30080, host: 30080, auto_correct: true
end
```

Then you can access the app from your Fedora host:

```bash
curl http://localhost:30080
```

---

## 📚 References

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Libvirt on Fedora](https://docs.fedoraproject.org/en-US/quick-docs/getting-started-with-virtualization/)
- [Kubernetes Dashboard](https://github.com/kubernetes/dashboard)

---

> 🛡️ For educational and local testing only. Do not expose this cluster to the Internet without securing it.