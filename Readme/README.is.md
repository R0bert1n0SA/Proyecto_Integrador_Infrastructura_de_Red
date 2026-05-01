# Samþættur Verkefni — Netkerfi Innviðar

Fullkomið sýndarvæðt netkerfi með Vagrant, VirtualBox og Ansible. Inniheldur yfirvald DNS, DHCP með kvikum DNS (DDNS), LDAP skrá, SFTP þjón með chroot-búr og Ubuntu biðlara með miðlægar innskráningar.

---

## Uppbygging

```
┌─────────────────────────────────────────────────────┐
│               Innra net (intnet)                    │
│               192.168.58.0/24                       │
│                                                     │
│  Fastar DNS/DHCP             Kvik LDAP/SFTP         │
│  ┌──────────┐            ┌──────────┐               │
│  │   DNS    │◄───DDNS────│   DHCP   │               │
│  │ .58.2    │            │ .58.3    │               │
│  └──────────┘            └──────────┘               │
│       ▲                       ▲                     │
│       │ auth.luthor.corp      │ kvik IP             │
│       │ sftp.luthor.corp      │                     │
│  ┌──────────┐            ┌──────────┐               │
│  │   LDAP   │◄───notend──│   SFTP   │               │
│  │  kvik    │            │  kvik    │               │
│  └──────────┘            └──────────┘               │
│            ▲         ▲                              │
│            │  Ubuntu  │                             │
│            │  biðlari │                             │
│            └──────────┘                             │
└─────────────────────────────────────────────────────┘
```

### Þjónar

| Þjónn | IP | Hlutverk |
|---|---|---|
| DNS | 192.168.58.2 (föst) | BIND9 yfirvald fyrir `luthor.corp` |
| DHCP | 192.168.58.3 (föst) | ISC DHCP + DDNS til DNS |
| LDAP | kvik í gegnum DHCP | OpenLDAP + Samba schema |
| SFTP | kvik í gegnum DHCP | OpenSSH með chroot-búr + nslcd |
| Biðlari | kvik í gegnum DHCP | Ubuntu Desktop, LDAP auðkenning |

---

## Hönnunarákvarðanir

### DDNS í stað fastrar IP fyrir LDAP og SFTP

Hefðbundin venja mælir með fastri IP fyrir þjóna. Í þessum verkefni var valið að nota DHCP með MAC-frátekningum + DDNS til að sýna fram á hvernig kvik DNS-uppfærsla virkar. DNS og DHCP þjónarnir hafa enn fastar IP-tölur þar sem þeir mynda grunninn að innviðunum.

DHCP þjónninn staðfestir uppfærslur sínar til DNS með **TSIG** (Transaction Signature með HMAC-SHA256), sem tryggir að aðeins viðurkenndur DHCP-þjónn geti breytt DNS-færslum.

### OpenLDAP frekar en Active Directory

OpenLDAP var valið til að viðhalda 100% Linux-umhverfi, án Windows-háða. OpenLDAP er nánast staðall í Linux-innviðum og leyfir innfætt samþætti við PAM, NSS og Samba.

### SFTP með chroot-búr

SFTP þjónninn auðkennir notendur á móti LDAP í gegnum nslcd. Notendur í hópnum `SFTPUsers` eru lokaðir inni í `/srv/Chroot` með `upload` og `download` möppum. Hópurinn samstillir sig sjálfkrafa frá LDAP í gegnum skript sem keyrir með cron.

### Ubuntu biðlari með myndrænt viðmót

Biðlarinn er ræstur sem sýndarvél með Ubuntu Desktop. Hann auðkennist á móti LDAP, leysir nöfn upp í gegnum eigin DNS innviðanna (`auth.luthor.corp`, `sftp.luthor.corp`) og opnar SFTP með LDAP-aðgangsupplýsingum sínum.

### VirtualBox innra net (intnet)

`virtualbox__intnet` er notað í stað `hostonly` vegna þess að hostonly-net VirtualBox sendir ekki broadcast á milli sýndarvéla, sem kemur í veg fyrir að DHCP samskiptareglur virki milli þjóna. Með `intnet` flæðir broadcast á réttan hátt.

---

## Kröfur

- [VirtualBox 7.1.12](https://www.virtualbox.org/)
- [Vagrant 2.4.9](https://www.vagrantup.com/)
- Ansible (sett upp á hýsilinn)
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

---

## Hvernig á að keyra verkefnið

### 1. Klóna geymslan

```bash
git clone https://github.com/NOTENDANAFN/Proyecto_Integrador_Infrastructura_de_Red.git
cd Proyecto_Integrador_Infrastructura_de_Red
```

### 2. Slökkva á innbyggðum DHCP VirtualBox

Nauðsynlegt til að DHCP innviðanna virki rétt:

```bash
VBoxManage dhcpserver modify --network "HostInterfaceNetworking-vboxnet0" --disable
```

### 3. Ræsa innviðina

```bash
vagrant up
```

Vagrant ræsir þjónana í röð: DNS → DHCP → LDAP → SFTP. Sérhver þjónn er sjálfkrafa stilltur með Ansible.

### 4. Staðfesta að allt virki

```bash
# Athuga IP-tölur úthlutaðar af DHCP
vagrant ssh servidor-ldap -c "ip a show enp0s8"
vagrant ssh sftp_server -c "ip a show enp0s8"

# Athuga DNS-uppflettingu
vagrant ssh dns_server -c "dig auth.luthor.corp"
vagrant ssh dns_server -c "dig sftp.luthor.corp"

# Athuga DHCP-leigu
vagrant ssh servidor-dhcp -c "cat /var/lib/dhcpd/dhcpd.leases"
```

---

## Uppbygging verkefnis

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

## Lén

`luthor.corp`

| Nafn | Leysist upp í |
|---|---|
| `ns.luthor.corp` | 192.168.58.2 |
| `auth.luthor.corp` | Kvik IP LDAP þjónsins |
| `sftp.luthor.corp` | Kvik IP SFTP þjónsins |

---

## LDAP Notendur

Notendur eru búnir til sjálfkrafa við uppsetningu. Þeir eru skipulagðir í OUs innan `dc=luthor,dc=corp`:

| OU | Hópar | Notendur |
|---|---|---|
| `ou=Users` | — | UserQA0-2, Useradministracion0-4, o.fl. |
| `ou=Groups` | soporte, desarrollo, administracion, rr-hh, QA, SFTPUsers | — |
| `ou=Machines` | — | — |
| `ou=Service` | — | servicioUser |

Sjálfgefið lykilorð LDAP-stjórnanda: `1234`

---

## Athugasemdir

- Slökkva verður á DHCP VirtualBox áður en `vagrant up` er keyrt, annars geta LDAP og SFTP fengið ranga IP-tölu.
- TSIG-lykillinn er búinn til sjálfkrafa á DNS þjóninum og DHCP þjónninn sækir hann í gegnum Ansible. Engin handvirk skref þarf.
- Ubuntu biðlarinn (enn í þróun) verður ræstur sem fimmta sýndarvélin með `vagrant up` þegar honum hefur verið bætt við Vagrantfile.
