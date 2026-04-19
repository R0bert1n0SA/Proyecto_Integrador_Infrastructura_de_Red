# Integrationsprojekt — Netzwerkinfrastruktur

Vollständig virtualisierte Netzwerkinfrastruktur mit Vagrant, VirtualBox und Ansible. Beinhaltet autoritativen DNS, DHCP mit dynamischem DNS (DDNS), LDAP-Verzeichnis, SFTP-Server mit Chroot-Jail und Ubuntu-Client mit zentralisierter Authentifizierung.

---

## Architektur (Auszug)

```
┌─────────────────────────────────────────────────────┐
│                   Internes Netzwerk (intnet)              │
│                   192.168.58.0/24                   │
│                                                     │
│  DNS/DHCP statisch          LDAP/SFTP dynamisch        │
│  ┌──────────┐            ┌──────────┐               │
│  │   DNS    │◄───DDNS────│   DHCP   │               │
│  │ .58.2    │            │ .58.3    │               │
│  └──────────┘            └──────────┘               │
│       ▲                       ▲                     │
│       │ auth.luthor.corp      │ IP Dynamische        │
│       │ sftp.luthor.corp      │                     │
│  ┌──────────┐            ┌──────────┐               │
│  │   LDAP   │◄───Benutzer───│   SFTP   │               │
│  │ Dynamische │            │ Dynamische │               │
│  └──────────┘            └──────────┘               │
│            ▲         ▲                              │
│            │  Ubuntu │                             │
│            │  Client  │                             │
│            └──────────┘                             │
└─────────────────────────────────────────────────────┘
```

### Servidores

| Servidor | IP | Rolle |
|---|---|---|
| DNS | 192.168.58.2 (statisch) | Autoritativer BIND9 für `luthor.corp` |
| DHCP | 192.168.58.3 (statisch) | ISC DHCP + DDNS zum  DNS |
| LDAP | dynamisch via DHCP | OpenLDAP + Samba schema |
| SFTP | dynamisch via DHCP | OpenSSH mit Chroot Jail + nslcd |
| Cliente | dynamisch via DHCP | Ubuntu Desktop, LDAP-Authentifizierung |

---

## Design-Entscheidungen

### DDNS statt statischer IPs für LDAP und SFTP

Obwohl Server standardmäßig statische IPs haben sollten, nutzt dieses Projekt DHCP mit MAC-Reservierungen + DDNS. Dies dient dazu, die Funktionsweise dynamischer DNS-Updates zu demonstrieren. DNS und DHCP behalten statische IPs, da sie das Fundament der Infrastruktur bilden.

Der DHCP-Server authentifiziert seine Updates am DNS mittels TSIG (Transaction Signature mit HMAC-SHA256). Dies stellt sicher, dass nur der autorisierte DHCP-Server DNS-Einträge ändern darf.

### OpenLDAP statt Active Directory

OpenLDAP wurde gewählt, um eine 100%ige Linux-Umgebung ohne Windows-Abhängigkeiten zu gewährleisten. OpenLDAP ist ein Standard in Linux-Infrastrukturen und ermöglicht eine native Integration mit PAM, NSS und Samba.

### SFTP mit Chroot-Jail

Der SFTP-Server authentifiziert Benutzer gegen LDAP via nslcd. Benutzer der Gruppe SFTPUsers werden in /srv/Chroot mit den Verzeichnissen upload und download eingesperrt. Die Gruppe wird automatisch über ein Cron-Script aus dem LDAP synchronisiert..

### Ubuntu Client mit grafischer Benutzeroberfläche

Der Client wird als VM mit Ubuntu Desktop gestartet. Er authentifiziert sich gegen LDAP, löst Namen über den eigenen DNS auf (auth.luthor.corp, sftp.luthor.corp) und greift mit LDAP-Zugangsdaten auf den SFTP zu

### Internes VirtualBox-Netzwerk (intnet)

Es wird virtualbox__intnet anstelle von hostonly verwendet, da das Host-Only-Netzwerk von VirtualBox keine Broadcasts zwischen VMs weiterleitet. Dies würde das DHCP-Protokoll verhindern. Mit intnet zirkulieren Broadcasts korrekt.

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

---

## Projekt ausführen

### 1. Repository klonen

```bash
git clone https://github.com/TU_USUARIO/Proyecto_Integrador_Infrastructura_de_Red.git
cd Proyecto_Integrador_Infrastructura_de_Red
```

### 2. Internen VirtualBox-DHCP deaktivieren

Dies ist notwendig, damit der DHCP-Server der Infrastruktur korrekt funktioniert:

```bash
VBoxManage dhcpserver modify --network "HostInterfaceNetworking-vboxnet0" --disable
```

### 3. Infrastruktur starten

```bash
vagrant up
```

Vagrant startet die Server in der Reihenfolge: DNS → DHCP → LDAP → SFTP. Jeder Server wird automatisch mit Ansible konfiguriert (Provisioning).

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
```

---

## Projektstruktur

```
Proyecto_Integrador_Infrastructura_de_Red/
├── Vagrantfile
├── site.yml
├── Inventary.ini
├── TareasComunes/
│   └── 01-sistema.yml
└── Roles/
    ├── dns/
    │   ├── tasks/
    │   ├── templates/
    │   │   ├── named_conf_options.j2
    │   │   ├── named_conf_local.j2
    │   │   ├── db_luthor_corp.j2
    │   │   └── db_58_168_192.j2
    │   └── vars/
    ├── dhcp/
    │   ├── tasks/
    │   ├── templates/
    │   │   ├── dhcpd_conf.j2
    │   │   └── isc-dhcp-server.j2
    │   └── vars/
    ├── ldap/
    │   ├── tasks/
    │   ├── templates/
    │   └── vars/
    └── sftp-ssh/
        ├── tasks/
        ├── templates/
        └── vars/
```

---

## Domain

`luthor.corp`

| Name | Auflösung zu |
|---|---|
| `ns.luthor.corp` | 192.168.58.2 |
| `auth.luthor.corp` | Dynamische IP des LDAP-server |
| `sftp.luthor.corp` | Dynamische IP des servidor SFTP-server |

---

## LDAP-Benutzer

Benutzer werden beim Provisioning automatisch erstellt. Sie sind in OUs (Organizational Units) innerhalb von `dc=luthor,dc=corp`organisiert:

| OU | Gruppen | Benutzer |
|---|---|---|
| `ou=Users` | — | UserQA0-2, Useradministracion0-4, etc. |
| `ou=Groups` | soporte, desarrollo, administracion, rr-hh, QA, SFTPUsers | — |
| `ou=Machines` | — | — |
| `ou=Service` | — | servicioUser |

Standard-Passwort für den LDAP-Administrator: `1234`

---

## Hinweise

- Der VirtualBox-eigene DHCP muss deaktiviert sein, bevor 'vagrant up' ausgeführt wird, da LDAP und SFTP sonst falsche IPs erhalten könnten.

- Der TSIG-Key wird automatisch auf dem DNS-Server generiert und vom DHCP-Server via Ansible abgerufen. Kein manueller Schritt erforderlich.

- Der Ubuntu-Client (Implementierung ausstehend) wird als fünfte VM mit 'vagrant up' gestartet, sobald er im Vagrantfile ergänzt wurde.
