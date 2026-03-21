Vagrant.configure("2") do |config|
  # Usamos Ubuntu 22.04 (Jammy)
  config.vm.box = "ubuntu/jammy64"
  
  # --- MÁQUINA 1: SERVIDOR LDAP ---
  config.vm.define "servidor-ldap" do |ldap|
    ldap.vm.network "private_network", ip: "192.168.58.4"
    ldap.vm.hostname = "ldap-server"

  ldap.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 1
    vb.name = "Servidor-LDAP"
  end

  # Crear usuario administrador para esta VM
  ldap.vm.provision "shell", inline: <<-SHELL
    useradd -m -s /bin/bash administrador-ldap
    echo "administrador-ldap:1234" |sudo chpasswd
    sudo usermod -aG sudo administrador-ldap
    echo "administrador-ldap ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/administrador-ldap
  SHELL

# Ejecutar Ansible SOLO con el tag 'ldap' en esta máquina
    ldap.vm.provision "ansible" do |ansible|
      ansible.playbook = "site.yml"
      # Pasamos la IP de esta misma máquina como servidor LDAP (por si el rol lo necesita)
      ansible.extra_vars = { 
        ansible_ssh_common_args: "-o StrictHostKeyChecking=no",
        ldap_server_ip: "192.168.58.4"
      }
      # IMPORTANTE: Asumiendo que en tu site.yml el rol de ldap tiene el tag "ldap"
      ansible.tags = ["ldap"]
    end
  end

  # --- MÁQUINA 2: SERVIDOR SFTP (Cliente de LDAP) ---
  config.vm.define "sftp_server" do |sftp|
    sftp.vm.network "private_network", ip: "192.168.58.5"
    sftp.vm.hostname = "sftp-server"

    sftp.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
      vb.name = "Servidor-SFTP"
    end

    # Crear usuario administrador para esta VM
    sftp.vm.provision "shell", inline: <<-SHELL
      useradd -m -s /bin/bash administrador-sftp
      echo "administrador-sftp:1234" | sudo chpasswd
      sudo usermod -aG sudo administrador-sftp
      echo "administrador-sftp ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/administrador-sftp
    SHELL

    # Ejecutar Ansible SOLO con el tag 'ssh-sftp' en esta máquina
    sftp.vm.provision "ansible" do |ansible|
      ansible.playbook = "site.yml"
      # Le pasamos la IP del SERVIDOR LDAP para que el cliente nslcd se conecte a él
      ansible.extra_vars = { 
        ansible_ssh_common_args: "-o StrictHostKeyChecking=no",
        ldap_server_ip: "192.168.58.4", 
        # Ajusta esto según tus variables del rol
        ldap_base_dn: "dc=luthor,dc=corp" 
      }
      # IMPORTANTE: Asumiendo que en tu site.yml el rol de ssh-sftp tiene el tag "sftp-ssh"
      ansible.tags = ["sftp-ssh"]
    end
  end
end



