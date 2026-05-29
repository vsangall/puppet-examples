Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "puppet-haproxy"

  # Network configuration
  config.vm.network "private_network", ip: "192.168.121.10"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "forwarded_port", guest: 443, host: 8443

  # VM resources for libvirt
  config.vm.provider "libvirt" do |lv|
    lv.memory = 2048
    lv.cpus = 2
    lv.title = "puppet-haproxy"
  end

  # Sync Puppet repo to VM using rsync
  config.vm.synced_folder ".", "/puppet-repo", type: "rsync", rsync__exclude: ".git/"

  # Install Puppet and apply manifests
  config.vm.provision "shell", path: "vagrant-provision.sh"
end
