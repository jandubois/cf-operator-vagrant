# -*- mode: ruby -*-
# vi: set ft=ruby :

def base_net_config
  {
    use_dhcp_assigned_default_route: true,
    ip: "192.168.77.77",
  }
end

Vagrant.configure(2) do |config|
  vm_memory = ENV.fetch('SCF_VM_MEMORY', ENV.fetch('VM_MEMORY', 10 * 1024)).to_i
  vm_cpus = ENV.fetch('SCF_VM_CPUS', ENV.fetch('VM_CPUS', 4)).to_i
  vm_box_version = ENV.fetch('SCF_VM_BOX_VERSION', ENV.fetch('VM_BOX_VERSION', '2.0.17'))
  vm_registry_mirror = ENV.fetch('SCF_VM_REGISTRY_MIRROR', ENV.fetch('VM_REGISTRY_MIRROR', ''))

  HOME = "/home/vagrant"

  config.vm.provider "virtualbox" do |vb, override|
    # Need to shorten the URL for Windows' sake.
    override.vm.box = "https://cf-opensusefs2.s3.amazonaws.com/vagrant/scf-virtualbox-v#{vm_box_version}.box"
    vb_net_config = base_net_config
    if ENV.include? "VAGRANT_VBOX_BRIDGE"
      vb_net_config[:bridge] = ENV.fetch("VAGRANT_VBOX_BRIDGE")
      override.vm.network "public_network", vb_net_config
    else
      # Create a private network, which allows host-only access to the machine.
      override.vm.network "private_network", vb_net_config
    end

    vb.memory = vm_memory.to_s
    vb.cpus = vm_cpus

    vb.customize ['modifyvm', :id, '--paravirtprovider', 'minimal']

    # https://github.com/mitchellh/vagrant/issues/351
    override.vm.synced_folder ".", "#{HOME}/setup", type: "nfs"
    override.vm.synced_folder "../cf-operator", "#{HOME}/cf-operator", type: "nfs"
  end

  # Adds the loop kernel module for loading on system startup, as well as loads it immediately.
  config.vm.provision :shell, privileged: true, inline: <<-SHELL
    echo "loop" > /etc/modules-load.d/loop.conf
    modprobe loop
  SHELL

  # Install common and dev tools.
  config.vm.provision :shell, privileged: true, inline: <<-SHELL
    set -o errexit -o xtrace -o verbose
    export HOME="#{HOME}"
    export PATH="#{HOME}/bin:${PATH}"

    if [ -n "#{vm_registry_mirror}" ]; then
      perl -p -i -e 's@^(DOCKER_OPTS=)"(.*)"@\\1"\\2 --registry-mirror=#{vm_registry_mirror}"@' /etc/sysconfig/docker
      # Docker has issues coming up on virtualbox; let it fail gracefully, if necessary.
      systemctl stop docker.service
      if ! systemctl restart docker.service ; then
        while [ "$(systemctl is-active docker.service)" != active ] ; do
          case "$(systemctl is-active docker.service)" in
            failed) systemctl reset-failed docker.service ;
                    systemctl restart docker.service ||: ;;
            *)      sleep 5                              ;;
          esac
        done
      fi
    fi
  SHELL

  # Ensure that kubelet is running correctly.
  config.vm.provision :shell, privileged: true, inline: <<-'SHELL'
    set -o errexit -o nounset -o xtrace
    if ! systemctl is-active kubelet.service ; then
      systemctl enable --now kubelet.service
    fi

    wget -q https://dl.google.com/go/go1.12.linux-amd64.tar.gz -O - | tar -C /usr/local -xz
  SHELL

  # Wait for the pods to be ready.
  config.vm.provision :shell, privileged: false, inline: <<-'SHELL'
    set -o errexit -o nounset
    echo "Waiting for pods to be ready..."
    for selector in k8s-app=kube-dns ; do
      while ! kubectl get pods --namespace=kube-system --selector "${selector}" 2> /dev/null | grep -Eq '([0-9])/\1 *Running' ; do
        sleep 5
      done
    done

    cd "${HOME}"
    wget -q https://github.com/SUSE/kctl/releases/download/v0.0.12/kctl-linux-amd64 -O bin/k
    chmod a+x bin/k

    echo "alias y2j='ruby -rjson -ryaml -e \\\"puts YAML.load(STDIN.read).to_json\\\"'" >> .profile
    echo 'export PATH="#{HOME}/bin:/usr/local/go/bin:${PATH}"' >> .profile

    ./setup/setup.sh
  SHELL
end
