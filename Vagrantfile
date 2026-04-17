Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
 
  servers = [
    {
      :name => "dns_server",
      :ip => "192.168.58.2",
      :hostname => "dns-server",
      :memory => 1024,
      :tag => "dns",
      :user => "administrador-dns"
    },
    {
      :name => "servidor-dhcp",
      :ip => "192.168.58.3",
      :hostname => "dhcp-server",
      :memory => 1024,
      :tag => "dhcp",
      :user => "administrador-dhcp"
    },
    {
      :name => "servidor-ldap",
      :hostname => "ldap-server",
      :memory => 1024,
      :tag => "ldap",
      :user => "administrador-ldap",
      :mac => "0800272f835c"
    },
    {
      :name => "sftp_server",
      :hostname => "sftp-server",
      :memory => 1024,
      :tag => "sftp-ssh",
      :user => "administrador-sftp",
      :mac => "08002781a587"
    },
    {
      :name => "cliente",
      :hostname => "cliente-gui",
      :memory => 4096,          # GUI necesita más RAM
      :cpus => 1,               # GUI necesita más CPU
      :tag => "cliente",
      :user => "administrador-cliente",
    }
  ]
 
  servers.each do |server|
    config.vm.define server[:name] do |node|
 
     if server[:ip]
         node.vm.network "private_network", ip: server[:ip],
         virtualbox__intnet: "red-interna"
      else
         node.vm.network "private_network", type: "dhcp",
         virtualbox__intnet: "red-interna"
      end
 
      node.vm.hostname = server[:hostname]
 
      node.vm.provider "virtualbox" do |vb|
        vb.memory = server[:memory]
        vb.cpus = server[:cpus] || 1
        vb.name = "#{server[:name].capitalize}"
        vb.customize ["modifyvm", :id, "--macaddress2", server[:mac]] if server[:mac]
 
        # Habilitar GUI solo para el cliente
        if server[:name] == "cliente"
          vb.gui = true
          vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
          vb.customize ["modifyvm", :id, "--vram", "128"]
          vb.customize ["modifyvm", :id, "--accelerate3d", "on"]
        end
      end
 
      node.vm.provision "shell", inline: <<-SHELL
        useradd -m -s /bin/bash #{server[:user]}
        echo "#{server[:user]}:1234" | sudo chpasswd
        sudo usermod -aG sudo #{server[:user]}
        echo "#{server[:user]} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/#{server[:user]}
      SHELL
 
      node.vm.provision "ansible" do |ansible|
        ansible.playbook = "site.yml"
        ansible.extra_vars = {
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no",
          ldap_server_ip: "192.168.58.4",
          ldap_base_dn: "dc=luthor,dc=corp"
        }
        ansible.tags = [server[:tag]]
      end
    end
  end
end
