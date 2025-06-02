# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

vagrant_root = File.expand_path(__dir__)
settings     = YAML.load_file("#{vagrant_root}/settings.yaml")

# ─── Build some helpers from settings ──────────────────────────────────────────
ip_match          = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/)
IP_NW             = ip_match[1]                      # "10.0.0."
IP_START          = ip_match[2].to_i                 # 10  (last octet)
NUM_WORKER_NODES  = settings["nodes"]["workers"]["count"]

# ─── Vagrant configuration ────────────────────────────────────────────────────
Vagrant.configure("2") do |config|
  # 1. Force the default /vagrant mount to use NFSv4/TCP.
  config.vm.synced_folder ".", "/vagrant",
    type:        "nfs",
    nfs_version: 4,
    nfs_udp:     false,
    mount_options: ["vers=4", "tcp"]

  # 2. Put host entries on every VM (and any other one-off tweaks).
  config.vm.provision "shell",
    privileged: true,
    run: "always",
    env: { "IP_NW" => IP_NW, "IP_START" => IP_START,
           "NUM_WORKER_NODES" => NUM_WORKER_NODES },
    inline: <<-SHELL
      # Ensure NFS client is present before first mount attempt
      apt-get update -y
      apt-get install -y nfs-common

      # Populate /etc/hosts for cluster node discovery
      echo "${IP_NW}${IP_START} controlplane" >> /etc/hosts
      for i in $(seq 1 ${NUM_WORKER_NODES}); do
        echo "${IP_NW}$((IP_START+i)) node0${i}" >> /etc/hosts
      done
    SHELL

  # 3. Select the correct box for architecture
  config.vm.box = (`uname -m`.strip == "aarch64") \
                    ? "#{settings['software']['box']}-arm64" \
                    : settings['software']['box']
  config.vm.box_check_update = true

  # Helper to add any extra host-defined shares using NFS v4.
  def add_extra_shares(vm_cfg, shared_folders)
    return unless shared_folders
    shared_folders.each do |sf|
      vm_cfg.vm.synced_folder sf["host_path"], sf["vm_path"],
        type:        "nfs",
        nfs_version: 4,
        nfs_udp:     false,
        mount_options: ["vers=4", "tcp"]
    end
  end

  # ─── Control-plane VM ────────────────────────────────────────────────────────
  config.vm.define "controlplane" do |cp|
    cp.vm.hostname = "controlplane"
    cp.vm.network "private_network", ip: settings["network"]["control_ip"]

    # Extra shared folders (if any were declared in settings.yaml)
    add_extra_shares(cp, settings["shared_folders"])

    # Resources using libvirt provider
    cp.vm.provider "libvirt" do |libvirt|
      libvirt.cpus   = settings["nodes"]["control"]["cpu"]
      libvirt.memory = settings["nodes"]["control"]["memory"]
      libvirt.nested = true
      libvirt.storage :file, :size => '20G'
    end

    # Cluster-bootstrap scripts
    cp.vm.provision "shell",
      env: {
        "DNS_SERVERS"            => settings["network"]["dns_servers"].join(" "),
        "ENVIRONMENT"            => settings["environment"],
        "KUBERNETES_VERSION"     => settings["software"]["kubernetes"],
        "KUBERNETES_VERSION_SHORT" => settings["software"]["kubernetes"][0..3],
        "OS"                     => settings["software"]["os"]
      },
      path: "scripts/common.sh"

    cp.vm.provision "shell",
      env: {
        "CALICO_VERSION" => settings["software"]["calico"],
        "CONTROL_IP"     => settings["network"]["control_ip"],
        "POD_CIDR"       => settings["network"]["pod_cidr"],
        "SERVICE_CIDR"   => settings["network"]["service_cidr"]
      },
      path: "scripts/master.sh"
  end

  # ─── Worker VMs ──────────────────────────────────────────────────────────────
  (1..NUM_WORKER_NODES).each do |i|
    config.vm.define "node0#{i}" do |node|
      node.vm.hostname = "node0#{i}"
      node.vm.network "private_network", ip: "#{IP_NW}#{IP_START + i}"

      add_extra_shares(node, settings["shared_folders"])

      node.vm.provider "libvirt" do |libvirt|
        libvirt.cpus   = settings["nodes"]["control"]["cpu"]
        libvirt.memory = settings["nodes"]["control"]["memory"]
        libvirt.nested = true
        libvirt.storage :file, :size => '20G'
      end

      node.vm.provision "shell",
        env: {
          "DNS_SERVERS"            => settings["network"]["dns_servers"].join(" "),
          "ENVIRONMENT"            => settings["environment"],
          "KUBERNETES_VERSION"     => settings["software"]["kubernetes"],
          "KUBERNETES_VERSION_SHORT" => settings["software"]["kubernetes"][0..3],
          "OS"                     => settings["software"]["os"]
        },
        path: "scripts/common.sh"

      node.vm.provision "shell", path: "scripts/node.sh"

      # Install the dashboard on the last worker (if enabled).
      if i == NUM_WORKER_NODES &&
         (dash = settings.dig("software", "dashboard")).to_s != ""
        node.vm.provision "shell", path: "scripts/dashboard.sh"
      end
    end
  end
end
