# Samþættur Verkefni — Netkerfi Innviðar

Fullkomið sýndarvæðt netkerfi með Vagrant, VirtualBox og Ansible. Inniheldur yfirvald DNS, DHCP með kvikum DNS (DDNS), LDAP skrá, SFTP þjón með chroot-búr, Ubuntu biðlara með miðlægar innskráningar og fullkomið eftirlit með Prometheus og Grafana.

---

## Tækni notuð í verkefninu

![Vagrant](https://img.shields.io/badge/Vagrant-1868F2?style=flat&logo=vagrant&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-183A61?style=flat&logo=virtualbox&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu_22.04-E95420?style=flat&logo=ubuntu&logoColor=white)

| Flokkur | Tækni |
|---|---|
| Sýndarvæðing | Vagrant + VirtualBox |
| Sjálfvirkni | Ansible |
| DNS | BIND9 + DDNS + TSIG |
| DHCP | ISC DHCP |
| Skráasafn | OpenLDAP + Samba schema |
| Auðkenning | PAM + nslcd + libpam-ldapd |
| Skráaflutningur | OpenSSH (SFTP) + chroot |
| Gámar | Docker + Docker Compose |
| Eftirlit | Prometheus + Grafana + Alertmanager |
| Mælingar | Node Exporter |

---

## Uppbygging

```
┌──────────────────────────────────────────────────────────┐
│               Innra net (intnet)                         │
│               192.168.58.0/24                            │
│                                                          │
│  Fastar DNS/DHCP             Kvik LDAP/SFTP              │
│  ┌──────────┐            ┌──────────┐                    │
│  │   DNS    │◄───DDNS────│   DHCP   │                    │
│  │ .58.2    │            │ .58.3    │                    │
│  └──────────┘            └──────────┘                    │
│       ▲                       ▲                          │
│       │ auth.luthor.corp      │ kvik IP                  │
│       │ sftp.luthor.corp      │                          │
│  ┌──────────┐            ┌──────────┐                    │
│  │   LDAP   │◄───notend──│   SFTP   │                    │
│  │  kvik    │            │  kvik    │                    │
│  └──────────┘            └──────────┘                    │
│       ▲              ▲        ▲              ▲           │
│       │   mælingar   │        │   mælingar   │           │
│  ┌──────────┐            ┌──────────┐                    │
│  │  Eftirl. │            │  Biðlari │                    │
│  │ .58.4    │            │  kvik    │                    │
│  └──────────┘            └──────────┘                    │
└──────────────────────────────────────────────────────────┘
```

### Þjónar

| Þjónn | IP | Hlutverk |
|---|---|---|
| DNS | 192.168.58.2 (föst) | BIND9 yfirvald fyrir `luthor.corp` |
| DHCP | 192.168.58.3 (föst) | ISC DHCP + DDNS til DNS |
| Eftirlit | 192.168.58.4 (föst) | Docker: Prometheus + Grafana + Alertmanager |
| LDAP | kvik í gegnum DHCP | OpenLDAP + Samba schema |
| SFTP | kvik í gegnum DHCP | OpenSSH með chroot-búr + nslcd |
| Biðlari | kvik í gegnum DHCP | Ubuntu Desktop, LDAP auðkenning |

---

## Hönnunarákvarðanir

### DDNS í stað fastrar IP fyrir LDAP og SFTP

Hefðbundin venja mælir með fastri IP. Í þessum verkefni var DHCP með MAC-frátekningum + DDNS notað til að sýna kvik DNS-uppfærslu. DNS, DHCP og eftirlitsþjónninn hafa fastar IP-tölur þar sem þeir mynda grunninn.

DHCP staðfestir uppfærslur til DNS með **TSIG** (HMAC-SHA256).

### OpenLDAP frekar en Active Directory

OpenLDAP var valið til að viðhalda 100% Linux-umhverfi. Það leyfir innfætt samþætti við PAM, NSS og Samba.

### SFTP með chroot-búr

SFTP auðkennir notendur á móti LDAP í gegnum nslcd. Notendur í `SFTPUsers` eru lokaðir inni í `/srv/Chroot`. Hópurinn samstillir sig sjálfkrafa frá LDAP með cron.

### Eftirlit með Docker

Eftirlitsþjónninn keyrir Prometheus, Grafana og Alertmanager í Docker-gámum. Node Exporter er sett upp beint á hverri sýndarvél og birtir mælingar á porti 9100. Docker tryggir að ef sýndarvélin er endurbyggð er allt uppi á loft með einu `docker compose up`.

### VirtualBox innra net (intnet)

`virtualbox__intnet` er notað vegna þess að hostonly-net sendir ekki broadcast á milli sýndarvéla.

---

## Kröfur

- [VirtualBox 7.1.12](https://www.virtualbox.org/)
- [Vagrant 2.4.9](https://www.vagrantup.com/)
- Ansible
- Git

### Setja upp Ansible á Ubuntu/Debian

```bash
sudo apt update
sudo apt install -y ansible
```

### Setja upp Ansible á macOS

```bash
brew install ansible
```

### Setja upp Ansible á Windows

Ansible keyrir ekki innfætt á Windows. Mælt er með **WSL2**:

**1. Virkja WSL2**
```powershell
# Keyra í PowerShell sem stjórnandi
wsl --install
# Endurræsa þegar beðið er um það
```

**2. Setja upp Ubuntu frá Microsoft Store**

Leita að "Ubuntu 22.04" í Microsoft Store og setja upp.

**3. Setja upp Ansible innan WSL2**
```bash
sudo apt update
sudo apt install -y ansible
```

**4. Setja upp VirtualBox og Vagrant á Windows** (venjulegir Windows-uppsetningarforrit)

**5. Stilla Vagrant fyrir WSL2**
```bash
# Innan WSL2
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"
```

> **Athugasemd:** Öll `vagrant`-skipun verður að keyra í WSL2-flugstöðinni, ekki í PowerShell eða CMD.

---

## Hvernig á að keyra verkefnið

### 1. Klóna geymslan

```bash
git clone https://github.com/R0bert1n0SA/Proyecto_Integrador_Infrastructura_de_Red.git
cd Proyecto_Integrador_Infrastructura_de_Red
```

### 2. Slökkva á innbyggðum DHCP VirtualBox

```bash
VBoxManage dhcpserver modify --network "HostInterfaceNetworking-vboxnet0" --disable
```

### 3. Ræsa innviðina

```bash
vagrant up
```

Vagrant ræsir þjónana í röð: DNS → DHCP → Eftirlit → LDAP → SFTP → Biðlari.

### 4. Staðfesta að allt virki

```bash
vagrant ssh servidor-ldap -c "ip a show enp0s8"
vagrant ssh sftp_server -c "ip a show enp0s8"
vagrant ssh dns_server -c "dig auth.luthor.corp"
vagrant ssh servidor-monitoreo -c "docker compose -f /opt/monitoreo/docker-compose.yml ps"
```

### 5. Aðgangur að eftirliti

| Þjónusta | Slóð | Notandi | Lykilorð |
|---|---|---|---|
| Grafana | http://192.168.58.4:3000 | admin | admin123 |
| Prometheus | http://192.168.58.4:9090 | — | — |
| Alertmanager | http://192.168.58.4:9093 | — | — |

---

## Lén

`luthor.corp`

| Nafn | Leysist upp í |
|---|---|
| `ns.luthor.corp` | 192.168.58.2 |
| `monitor.luthor.corp` | 192.168.58.4 |
| `auth.luthor.corp` | Kvik IP LDAP þjónsins |
| `sftp.luthor.corp` | Kvik IP SFTP þjónsins |

---

## LDAP Notendur

| OU | Hópar | Notendur |
|---|---|---|
| `ou=Users` | — | UserQA0-2, Useradministracion0-4, o.fl. |
| `ou=Groups` | soporte, desarrollo, administracion, rr-hh, QA, SFTPUsers | — |
| `ou=Machines` | — | — |
| `ou=Service` | — | servicioUser |

Sjálfgefið lykilorð LDAP-stjórnanda: `1234`

---

## Athugasemdir

- Slökkva verður á DHCP VirtualBox áður en `vagrant up` er keyrt.
- TSIG-lykillinn er búinn til sjálfkrafa. Engin handvirk skref þarf.
- Á Windows þarf WSL2. Sjá kröfuhlutann.
