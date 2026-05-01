# Integrating Project — Network Infrastructure

Complete virtualized network infrastructure using Vagrant, VirtualBox, and Ansible. Includes authoritative DNS, DHCP with dynamic DNS (DDNS), LDAP directory, SFTP server with chroot jail, and an Ubuntu client with centralized authentication.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Internal Network (intnet)          │
│                   192.168.58.0/24                   │
│                                                     │
│  Fixed DNS/DHCP              Dynamic LDAP/SFTP      │
│  ┌──────────┐            ┌──────────┐               │
│  │   DNS    │◄───DDNS────│   DHCP   │               │
│  │ .58.2    │            │ .58.3    │               │
│  └──────────┘            └──────────┘               │
│       ▲                       ▲                     │
│       │ auth.luthor.corp      │ dynamic IP          │
│       │ sftp.luthor.corp      │                     │
│  ┌──────────┐            ┌──────────┐               │
│  │   LDAP   │◄───users───│   SFTP   │               │
│  │ dynamic  │            │ dynamic  │               │
│  └──────────┘            └──────────┘               │
│            ▲         ▲                              │
│            │  Ubuntu  │                             │
│            │  Client  │                             │
│            └──────────┘                             │
└─────────────────────────────────────────────────────┘
```

### Servers

| Server | IP | Role |
|---|---|---|
| DNS | 192.168.58.2 (fixed) | BIND9 authoritative for `luthor.corp` |
| DHCP | 192.168.58.3 (fixed) | ISC DHCP + DDNS to DNS |
| LDAP | dynamic via DHCP | OpenLDAP + Samba schema |
| SFTP | dynamic via DHCP | OpenSSH with chroot jail + nslcd |
| Client | dynamic via DHCP | Ubuntu Desktop, LDAP auth |

---

## Design Decisions

### DDNS instead of fixed IPs for LDAP and SFTP

Standard practice recommends that servers use fixed IPs. In this project, DHCP with MAC reservations + DDNS was chosen to demonstrate how dynamic DNS updates work. The DNS and DHCP servers retain fixed IPs since they form the base of the infrastructure.

The DHCP server authenticates its updates to the DNS using **TSIG** (Transaction Signature with HMAC-SHA256), ensuring that only the authorized DHCP server can modify DNS records.

### OpenLDAP over Active Directory

OpenLDAP was chosen to maintain a 100% Linux environment, with no Windows dependencies. OpenLDAP is virtually a standard in Linux infrastructures and allows native integration with PAM, NSS, and Samba.

### SFTP with chroot jail

The SFTP server authenticates users against LDAP via nslcd. Users in the `SFTPUsers` group are jailed inside `/srv/Chroot` with `upload` and `download` directories. The group is automatically synchronized from LDAP via a cron-scheduled script.

### Ubuntu client with graphical interface

The client is launched as a VM with Ubuntu Desktop. It authenticates against LDAP, resolves names via the infrastructure's own DNS (`auth.luthor.corp`, `sftp.luthor.corp`), and accesses SFTP using its LDAP credentials.

### VirtualBox internal network (intnet)

`virtualbox__intnet` is used instead of `hostonly` because VirtualBox's hostonly network does not pass broadcasts between VMs, which prevents the DHCP protocol from working between servers. With `intnet`, broadcasts circulate correctly.

---

## Requirements

- [VirtualBox 7.1.12](https://www.virtualbox.org/)
- [Vagrant 2.4.9](https://www.vagrantup.com/)
- Ansible (installed on the host)
- Git

### Install Ansible on Ubuntu/Debian

```bash
sudo apt update
sudo apt install -y ansible
```

### Install Ansible on macOS

```bash
brew install ansible
```

---

## How to Run the Project

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/Proyecto_Integrador_Infrastructura_de_Red.git
cd Proyecto_Integrador_Infrastructura_de_Red
```

### 2. Disable VirtualBox's internal DHCP

Required for the infrastructure's DHCP to work correctly:

```bash
VBoxManage dhcpserver modify --network "HostInterfaceNetworking-vboxnet0" --disable
```

### 3. Bring up the infrastructure

```bash
vagrant up
```

Vagrant brings up the servers in order: DNS → DHCP → LDAP → SFTP. Each one is automatically provisioned with Ansible.

### 4. Verify everything is working

```bash
# Check IPs assigned by DHCP
vagrant ssh servidor-ldap -c "ip a show enp0s8"
vagrant ssh sftp_server -c "ip a show enp0s8"

# Check DNS resolution
vagrant ssh dns_server -c "dig auth.luthor.corp"
vagrant ssh dns_server -c "dig sftp.luthor.corp"

# Check DHCP leases
vagrant ssh servidor-dhcp -c "cat /var/lib/dhcpd/dhcpd.leases"
```

---

## Project Structure

```
Proyecto_Integrador_Infrastructura_de_Red/
├── Vagrantfile
├── site.yml
├── Inventary.ini
├── README.md                          
├── Readme/
│   ├── README_es.md
│   ├── README_en.md
│   ├── README_de.md
│   └── README_is.md
├── TareasComunes/
│   ├── 01-sistema.yml
│   └── 02-nslcd.yml
└── roles/
    ├── dns/
    │   ├── defaults/
    │   ├── files/
    │   ├── handlers/
    │   ├── meta/
    │   ├── tasks/
    │   │  ├── main.yml
    │   │  ├── 02-InstalarDependencias.yml
    │   │  └── 03-GenerarTSIG.yml
    │   ├── templates/
    │   │   ├── named.conf.options.j2
    │   │   ├── named.conf.local.j2
    │   │   ├── db.luthor.corp.j2
    │   │   └── db.58.168.192.j2
    │   ├── tests/
    │   └── vars/
    │       └── main.yml
    ├── dhcp/
    │   ├── defaults/
    │   ├── files/
    │   ├── handlers/
    │   ├── meta/
    │   ├── tasks/
    │   │  ├── main.yml
    │   │  ├── 02-ObtenerTSIG.yml
    │   │  └── 03-Instalar-DHCP.yml
    │   ├── templates/
    │   │   ├── dhcpd_conf.j2
    │   │   └── isc-dhcp-server.j2
    │   ├── tests/
    │   └── vars/
    │         └── main.yml
    ├── ldap/
    │   ├── defaults/
    │   ├── files/
    │   │   ├── Crear.sh
    │   │   ├── ActualizarSFTP.sh
    │   │   └── userPlantilla.ldif
    │   │   └── groupPlantilla.ldif
    │   │   └── ouPlantilla.ldif
    │   ├── handlers/
    │   │  ├── main.yml
    │   ├── meta/
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── 02-CopiarPlantillas.yml
    │   │   ├── 03-slapd.yml
    │   │   ├── 04-samba.yml
    │   │   ├── 05-Crear-Elementos-LDAP.yml
    │   │   ├── 07-ModoAnonimo-ACL.yml
    │   │   └── 08-SFTPUsers-Group.yml
    │   ├── templates/
    │   │   ├── smb.conf.j2
    │   │   └── BannedUsers.txt.j2
    │   ├── tests/
    │   └── vars/
    │	       └── main.yml
    ├── sftp-ssh/
    │   ├── defaults/
    │   ├── files/
    │   ├── handlers/
    │   ├── meta/
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── 02-resolv-config.yml
    │   │   ├── 03-Pam-config.yml
    │   │   ├── 04-Administradores.yml
    │   │   └── 05-Chroot.yml
    │   ├── templates/
    │   │   ├── sshd_config.j2
    │   │   ├── sudoers_admins.j2
    │   │   ├── common-auth.j2
    │   │   ├── common-account.j2
    │   │   └── common-session.j2
    │   ├── tests/
    │   └── vars/
    │       └── main.yml
    └── cliente/
        ├── defaults/
        ├── files/
        ├── handlers/
        ├── meta/
        ├── tasks/
        │   ├── main.yml
        │   └── 03-Config-PAM.yml
        ├── templates/
        ├── tests/
        └── vars/
             └── main.yml
```

---

## Domain

`luthor.corp`

| Name | Resolves to |
|---|---|
| `ns.luthor.corp` | 192.168.58.2 |
| `auth.luthor.corp` | Dynamic IP of the LDAP server |
| `sftp.luthor.corp` | Dynamic IP of the SFTP server |

---

## LDAP Users

Users are created automatically during provisioning. They are organized into OUs within `dc=luthor,dc=corp`:

| OU | Groups | Users |
|---|---|---|
| `ou=Users` | — | UserQA0-2, Useradministracion0-4, etc. |
| `ou=Groups` | soporte, desarrollo, administracion, rr-hh, QA, SFTPUsers | — |
| `ou=Machines` | — | — |
| `ou=Service` | — | servicioUser |

Default LDAP administrator password: `1234`

---

## Notes

- VirtualBox's DHCP must be disabled before running `vagrant up`, otherwise LDAP and SFTP may receive incorrect IPs.
- The TSIG key is generated automatically on the DNS server and the DHCP server retrieves it via Ansible. No manual steps are required.
- The Ubuntu client (pending implementation) will be brought up as a fifth VM with `vagrant up` once added to the Vagrantfile.
