# Integrating Project — Network Infrastructure

Complete virtualized network infrastructure using Vagrant, VirtualBox, and Ansible. Includes authoritative DNS, DHCP with dynamic DNS (DDNS), LDAP directory, SFTP server with chroot jail, Ubuntu client with centralized authentication, and full monitoring with Prometheus and Grafana.

---

## Technologies Used

![Vagrant](https://img.shields.io/badge/Vagrant-1868F2?style=flat&logo=vagrant&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-183A61?style=flat&logo=virtualbox&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu_22.04-E95420?style=flat&logo=ubuntu&logoColor=white)

| Category | Technology |
|---|---|
| Virtualization | Vagrant + VirtualBox |
| Automation | Ansible |
| DNS | BIND9 + DDNS + TSIG |
| DHCP | ISC DHCP |
| Directory | OpenLDAP + Samba schema |
| Authentication | PAM + nslcd + libpam-ldapd |
| File Transfer | OpenSSH (SFTP) + chroot |
| Containers | Docker + Docker Compose |
| Monitoring | Prometheus + Grafana + Alertmanager |
| Metrics | Node Exporter |

---

## Architecture

<img src="" width="800">


### Servers

| Server | IP | Role |
|---|---|---|
| DNS | 192.168.58.2 (fixed) | BIND9 authoritative for `luthor.corp` |
| DHCP | 192.168.58.3 (fixed) | ISC DHCP + DDNS to DNS |
| Monitoring | 192.168.58.4 (fixed) | Docker: Prometheus + Grafana + Alertmanager |
| LDAP | dynamic via DHCP | OpenLDAP + Samba schema |
| SFTP | dynamic via DHCP | OpenSSH with chroot jail + nslcd |
| Client | dynamic via DHCP | Ubuntu Desktop, LDAP auth |

---

## Design Decisions

### DDNS instead of fixed IPs for LDAP and SFTP

Standard practice recommends that servers use fixed IPs. In this project, DHCP with MAC reservations + DDNS was chosen to demonstrate how dynamic DNS updates work. The DNS, DHCP, and monitoring servers retain fixed IPs since they form the base of the infrastructure.

The DHCP server authenticates its updates to the DNS using **TSIG** (Transaction Signature with HMAC-SHA256), ensuring that only the authorized DHCP server can modify DNS records.

### OpenLDAP over Active Directory

OpenLDAP was chosen to maintain a 100% Linux environment, with no Windows dependencies. OpenLDAP is virtually a standard in Linux infrastructures and allows native integration with PAM, NSS, and Samba.

### SFTP with chroot jail

The SFTP server authenticates users against LDAP via nslcd. Users in the `SFTPUsers` group are jailed inside `/srv/Chroot` with `upload` and `download` directories. The group is automatically synchronized from LDAP via a cron-scheduled script.

### Monitoring with Docker

The monitoring server runs Prometheus, Grafana, and Alertmanager inside Docker containers. Each VM has Node Exporter installed directly, exposing CPU, RAM, disk, and network metrics on port 9100. Prometheus collects them every 15 seconds and Grafana visualizes them in dashboards. Using Docker for the monitoring stack means if the VM is recreated, the entire environment is restored with a single `docker compose up`.

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

### Install Ansible on Windows

Ansible does not run natively on Windows. The recommended approach is to use **WSL2** (Windows Subsystem for Linux):

**1. Enable WSL2**
```powershell
# Run in PowerShell as Administrator
wsl --install
# Restart when prompted
```

**2. Install Ubuntu from the Microsoft Store**

Search for "Ubuntu 22.04" in the Microsoft Store and install it.

**3. Inside WSL2, install Ansible**
```bash
sudo apt update
sudo apt install -y ansible
```

**4. Install VirtualBox and Vagrant on Windows** (standard Windows installers)

**5. Configure Vagrant to use WSL2**
```bash
# Inside WSL2
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"
```

> **Note:** All `vagrant` commands must be run from the WSL2 terminal, not from PowerShell or CMD.

---

## How to Run the Project

### 1. Clone the repository

```bash
git clone https://github.com/R0bert1n0SA/Proyecto_Integrador_Infrastructura_de_Red.git
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

Vagrant brings up the servers in order: DNS → DHCP → Monitoring → LDAP → SFTP → Client. Each one is automatically provisioned with Ansible.

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

# Check monitoring containers
vagrant ssh servidor-monitoreo -c "docker compose -f /opt/monitoreo/docker-compose.yml ps"
```

### 5. Access the monitoring stack

| Service | URL | User | Password |
|---|---|---|---|
| Grafana | http://192.168.58.4:3000 | admin | admin123 |
| Prometheus | http://192.168.58.4:9090 | — | — |
| Alertmanager | http://192.168.58.4:9093 | — | — |

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
│   ├── 02-nslcd.yml
│   └── node-exporter.yml
└── roles/
    ├── dns/
    ├── dhcp/
    ├── monitoreo/
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── 01-docker.yml
    │   │   └── 02-compose.yml
    │   ├── templates/
    │   │   ├── docker-compose.yml.j2
    │   │   └── datasource.yml.j2
    │   ├── files/
    │   │   ├── prometheus.yml
    │   │   ├── alerts.yml
    │   │   └── alertmanager.yml
    │   └── vars/main.yml
    ├── ldap/
    ├── sftp-ssh/
    └── cliente/
```

---

## Domain

`luthor.corp`

| Name | Resolves to |
|---|---|
| `ns.luthor.corp` | 192.168.58.2 |
| `monitor.luthor.corp` | 192.168.58.4 |
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
- On Windows, WSL2 is required to run Ansible. See the requirements section.
