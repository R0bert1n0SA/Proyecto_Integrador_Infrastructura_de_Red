Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

      servers = [
    {
      :name => "dns_server",
      :ip => "192.168.58.2",
      :hostname => "dns-server",
      :memory => 2048,
      :tag => "dns",
      :user => "administrador-dns"
    },
    {
      :name => "servidor-ldap",
      :ip => "192.168.58.4",
      :hostname => "ldap-server",
      :memory => 2048,
      :tag => "ldap",
      :user => "administrador-ldap"
    },
    {
      :name => "sftp_server",
      :ip => "192.168.58.5",
      :hostname => "sftp-server",
      :memory => 1024,
      :tag => "sftp-ssh",
      :user => "administrador-sftp"
    }
  ]

  # Bucle para crear cada máquina automáticamente
  servers.each do |server|
    config.vm.define server[:name] do |node|
      node.vm.network "private_network", ip: server[:ip]
      node.vm.hostname = server[:hostname]

      node.vm.provider "virtualbox" do |vb|
        vb.memory = server[:memory]
        vb.cpus = 1
        vb.name = "Servidor-#{server[:name].capitalize}"
      end

      # Crear usuario administrador dinámicamente según la máquina
      node.vm.provision "shell", inline: <<-SHELL
        useradd -m -s /bin/bash #{server[:user]}
        echo "#{server[:user]}:1234" | sudo chpasswd
        sudo usermod -aG sudo #{server[:user]}
        echo "#{server[:user]} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/#{server[:user]}
      SHELL

      # Ejecutar Ansible con el tag correspondiente
      node.vm.provision "ansible" do |ansible|
        ansible.playbook = "site.yml"
        ansible.extra_vars = { 
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no",
          ldap_server_ip: server[:name] == "dns_server" ? server[:ip] : "192.168.58.4",
          ldap_base_dn: "dc=luthor,dc=corp" 
        }
        ansible.tags = [server[:tag]]
      end
    end
  end
end
