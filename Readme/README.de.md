# Integrationsprojekt — Netzwerkinfrastruktur

Vollständig virtualisierte Netzwerkinfrastruktur mit Vagrant, VirtualBox und Ansible. Beinhaltet autoritativen DNS, DHCP mit dynamischem DNS (DDNS), LDAP-Verzeichnis, SFTP-Server mit Chroot-Jail, Ubuntu-Client mit zentralisierter Authentifizierung und vollständiges Monitoring mit Prometheus und Grafana.

---

## Verwendete Technologien

![Vagrant](https://img.shields.io/badge/Vagrant-1868F2?style=flat&logo=vagrant&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-183A61?style=flat&logo=virtualbox&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu_22.04-E95420?style=flat&logo=ubuntu&logoColor=white)

| Kategorie | Technologie |
|---|---|
| Virtualisierung | Vagrant + VirtualBox |
| Automatisierung | Ansible |
| DNS | BIND9 + DDNS + TSIG |
| DHCP | ISC DHCP |
| Verzeichnis | OpenLDAP + Samba schema |
| Authentifizierung | PAM + nslcd + libpam-ldapd |
| Dateiübertragung | OpenSSH (SFTP) + chroot |
| Container | Docker + Docker Compose |
| Monitoring | Prometheus + Grafana + Alertmanager |
| Metriken | Node Exporter |

---

## Architektur

<img width="1264" height="842" alt="Image" src="https://github.com/user-attachments/assets/7f79c411-3651-4b92-b0c8-3ed7fad74689" />

## Grafana 

<img width="1361" height="623" alt="Image" src="https://github.com/user-attachments/assets/e174c583-711f-4372-acd1-4f7b301a8d77" />

### Server

| Server | IP | Rolle |
|---|---|---|
| DNS | 192.168.58.2 (statisch) | Autoritativer BIND9 für `luthor.corp` |
| DHCP | 192.168.58.3 (statisch) | ISC DHCP + DDNS zum DNS |
| Monitoring | 192.168.58.4 (statisch) | Docker: Prometheus + Grafana + Alertmanager |
| LDAP | dynamisch via DHCP | OpenLDAP + Samba schema |
| SFTP | dynamisch via DHCP | OpenSSH mit Chroot Jail + nslcd |
| Client | dynamisch via DHCP | Ubuntu Desktop, LDAP-Authentifizierung |

---

## Design-Entscheidungen

### DDNS statt statischer IPs für LDAP und SFTP

Obwohl Server standardmäßig statische IPs haben sollten, nutzt dieses Projekt DHCP mit MAC-Reservierungen + DDNS, um die Funktionsweise dynamischer DNS-Updates zu demonstrieren. DNS, DHCP und der Monitoring-Server behalten statische IPs, da sie das Fundament der Infrastruktur bilden.

Der DHCP-Server authentifiziert seine Updates am DNS mittels **TSIG** (Transaction Signature mit HMAC-SHA256), sodass nur der autorisierte DHCP-Server DNS-Einträge ändern darf.

### OpenLDAP statt Active Directory

OpenLDAP wurde gewählt, um eine 100%ige Linux-Umgebung ohne Windows-Abhängigkeiten zu gewährleisten. OpenLDAP ist ein Standard in Linux-Infrastrukturen und ermöglicht native Integration mit PAM, NSS und Samba.

### SFTP mit Chroot-Jail

Der SFTP-Server authentifiziert Benutzer gegen LDAP via nslcd. Benutzer der Gruppe `SFTPUsers` werden in `/srv/Chroot` mit den Verzeichnissen `upload` und `download` eingesperrt. Die Gruppe wird automatisch über ein Cron-Script aus dem LDAP synchronisiert.

### Monitoring mit Docker

Der Monitoring-Server betreibt Prometheus, Grafana und Alertmanager in Docker-Containern. Auf jeder VM ist Node Exporter direkt installiert und stellt CPU-, RAM-, Festplatten- und Netzwerkmetriken auf Port 9100 bereit. Prometheus sammelt diese alle 15 Sekunden, Grafana visualisiert sie in Dashboards. Docker stellt sicher, dass bei einer Neuanlage der VM alles mit einem einzigen `docker compose up` wiederhergestellt wird.

### Internes VirtualBox-Netzwerk (intnet)

`virtualbox__intnet` wird anstelle von `hostonly` verwendet, da das Host-Only-Netzwerk von VirtualBox keine Broadcasts zwischen VMs weiterleitet. Mit `intnet` zirkulieren Broadcasts korrekt.

---

## Voraussetzungen

- [VirtualBox 7.1.12](https://www.virtualbox.org/)
- [Vagrant 2.4.9](https://www.vagrantup.com/)
- Ansible (auf dem Host installiert)
- Git

### Ansible unter Ubuntu/Debian installieren

```bash
sudo apt update
sudo apt install -y ansible
```

### Ansible unter macOS installieren

```bash
brew install ansible
```

### Ansible unter Windows installieren

Ansible läuft nicht nativ unter Windows. Die empfohlene Methode ist **WSL2** (Windows Subsystem for Linux):

**1. WSL2 aktivieren**
```powershell
# In PowerShell als Administrator ausführen
wsl --install
# Nach Aufforderung neu starten
```

**2. Ubuntu aus dem Microsoft Store installieren**

Im Microsoft Store nach "Ubuntu 22.04" suchen und installieren.

**3. Ansible in WSL2 installieren**
```bash
sudo apt update
sudo apt install -y ansible
```

**4. VirtualBox und Vagrant unter Windows installieren** (normale Windows-Installer)

**5. Vagrant für WSL2 konfigurieren**
```bash
# Innerhalb von WSL2
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"
```

> **Hinweis:** Alle `vagrant`-Befehle müssen im WSL2-Terminal ausgeführt werden, nicht in PowerShell oder CMD.

---

## Projekt ausführen

### 1. Repository klonen

```bash
git clone https://github.com/R0bert1n0SA/Proyecto_Integrador_Infrastructura_de_Red.git
cd Proyecto_Integrador_Infrastructura_de_Red
```

### 2. Internen VirtualBox-DHCP deaktivieren

```bash
VBoxManage dhcpserver modify --network "HostInterfaceNetworking-vboxnet0" --disable
```

### 3. Infrastruktur starten

```bash
vagrant up
```

Vagrant startet die Server in der Reihenfolge: DNS → DHCP → Monitoring → LDAP → SFTP → Client.

### 4. Funktionsprüfung

```bash
# Per DHCP zugewiesene IPs prüfen
vagrant ssh servidor-ldap -c "ip a show enp0s8"
vagrant ssh sftp_server -c "ip a show enp0s8"

# DNS-Auflösung prüfen
vagrant ssh dns_server -c "dig auth.luthor.corp"
vagrant ssh dns_server -c "dig sftp.luthor.corp"

# DHCP-Leases prüfen
vagrant ssh servidor-dhcp -c "cat /var/lib/dhcpd/dhcpd.leases"

# Monitoring-Container prüfen
vagrant ssh servidor-monitoreo -c "docker compose -f /opt/monitoreo/docker-compose.yml ps"
```

### 5. Monitoring-Zugriff

| Dienst | URL | Benutzer | Passwort |
|---|---|---|---|
| Grafana | http://192.168.58.4:3000 | admin | admin123 |
| Prometheus | http://192.168.58.4:9090 | — | — |
| Alertmanager | http://192.168.58.4:9093 | — | — |

---

## Domain

`luthor.corp`

| Name | Auflösung |
|---|---|
| `ns.luthor.corp` | 192.168.58.2 |
| `monitor.luthor.corp` | 192.168.58.4 |
| `auth.luthor.corp` | Dynamische IP des LDAP-Servers |
| `sftp.luthor.corp` | Dynamische IP des SFTP-Servers |

---

## LDAP-Benutzer

| OU | Gruppen | Benutzer |
|---|---|---|
| `ou=Users` | — | UserQA0-2, Useradministracion0-4, etc. |
| `ou=Groups` | soporte, desarrollo, administracion, rr-hh, QA, SFTPUsers | — |
| `ou=Machines` | — | — |
| `ou=Service` | — | servicioUser |

Standard-Passwort für den LDAP-Administrator: `1234`

---

## Hinweise

- Der VirtualBox-eigene DHCP muss vor `vagrant up` deaktiviert sein.
- Der TSIG-Key wird automatisch generiert. Kein manueller Schritt erforderlich.
- Unter Windows ist WSL2 erforderlich. Siehe Abschnitt Voraussetzungen.
