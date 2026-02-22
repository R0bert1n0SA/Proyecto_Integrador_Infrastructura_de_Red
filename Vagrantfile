Vagrant.configure("2") do |config|
  # Usamos Ubuntu 22.04 (Jammy)
  config.vm.box = "ubuntu/jammy64"
  
  # IP fija para que el inventario no cambie
  config.vm.network "private_network", ip: "192.168.56.3"

  config.vm.provider "servidor ldap" do |vb|
    vb.memory = "2048"
    vb.cpus = 1
    vb.name = "Servidor-LDAP"
  end


  config.vm.provision "shell", inline: <<-SHELL
    useradd -m -s /bin/bash administrador-ldap
    echo "administrador-ldap:1234" |sudo chpasswd
    sudo usermod -aG sudo administrador-ldap
    echo "administrador-ldap ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/administrador-ldap
  SHELL



  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "site-ldaptest.yml"
    # Esto es para que no te pida confirmación de huella digital SSH
    ansible.extra_vars = { ansible_ssh_common_args: "-o StrictHostKeyChecking=no" }
  end
end

