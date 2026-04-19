# Proyecto Integrador — Infraestructura de Red

Infraestructura de red completa virtualizada con Vagrant, VirtualBox y Ansible. Incluye DNS autoritativo, DHCP con DNS dinámico (DDNS), directorio LDAP, servidor SFTP con jaula y cliente Ubuntu con autenticación centralizada.

---

## Arquitectura

```
┌─────────────────────────────────────────────────────┐
│                   Red Interna (intnet)               │
│                   192.168.58.0/24                   │
│                                                     │
│  DNS/DHCP fijos          LDAP/SFTP dinámicos        │
│  ┌──────────┐            ┌──────────┐               │
│  │   DNS    │◄───DDNS────│   DHCP   │               │
│  │ .58.2    │            │ .58.3    │               │
│  └──────────┘            └──────────┘               │
│       ▲                       ▲                     │
│       │ auth.luthor.corp      │ IP dinámica         │
│       │ sftp.luthor.corp      │                     │
│  ┌──────────┐            ┌──────────┐               │
│  │   LDAP   │◄───users───│   SFTP   │               │
│  │ dinámica │            │ dinámica │               │
│  └──────────┘            └──────────┘               │
│            ▲         ▲                              │
│            │  Cliente │                             │
│            │  Ubuntu  │                             │
│            └──────────┘                             │
└─────────────────────────────────────────────────────┘
```

### Servidores

| Servidor | IP | Rol |
|---|---|---|
| DNS | 192.168.58.2 (fija) | BIND9 autoritativo para `luthor.corp` |
| DHCP | 192.168.58.3 (fija) | ISC DHCP + DDNS hacia el DNS |
| LDAP | dinámica vía DHCP | OpenLDAP + Samba schema |
| SFTP | dinámica vía DHCP | OpenSSH con jaula chroot + nslcd |
| Cliente | dinámica vía DHCP | Ubuntu Desktop, auth LDAP |

---

## Decisiones de diseño

### DDNS en lugar de IP fija para LDAP y SFTP

La práctica estándar indica que los servidores deberían tener IP fija. En este proyecto se decidió usar DHCP con reservas por MAC + DDNS para demostrar cómo funciona la actualización dinámica del DNS. El DNS y el DHCP sí mantienen IP fija ya que son la base de la infraestructura.

El DHCP autentica sus actualizaciones al DNS mediante **TSIG** (Transaction Signature con HMAC-SHA256), garantizando que solo el DHCP autorizado puede modificar los registros DNS.

### OpenLDAP sobre Active Directory

Se eligió OpenLDAP para mantener un entorno 100% Linux, sin dependencias de Windows. OpenLDAP es prácticamente un estándar en infraestructuras Linux y permite integración nativa con PAM, NSS y Samba.

### SFTP con jaula chroot

El servidor SFTP autentica usuarios contra LDAP mediante nslcd. Los usuarios del grupo `SFTPUsers` quedan enjaulados en `/srv/Chroot` con directorios `upload` y `download`. El grupo se sincroniza automáticamente desde LDAP mediante un script que corre vía cron.

### Cliente Ubuntu con interfaz gráfica

El cliente se levanta como VM con Ubuntu Desktop. Se autentica contra LDAP, resuelve nombres vía el DNS propio de la infraestructura (`auth.luthor.corp`, `sftp.luthor.corp`) y accede al SFTP con sus credenciales LDAP.

### Red interna VirtualBox (intnet)

Se usa `virtualbox__intnet` en lugar de `hostonly` porque la red hostonly de VirtualBox no pasa broadcasts entre VMs, lo que impide que el protocolo DHCP funcione entre servidores. Con `intnet` los broadcasts circulan correctamente.

---

## Requisitos

- [VirtualBox 7.1.12](https://www.virtualbox.org/)
- [Vagrant 2.4.9](https://www.vagrantup.com/)
- Ansible (instalado en el host)
- Git

### Instalar Ansible en Ubuntu/Debian

```bash
sudo apt update
sudo apt install -y ansible
```

### Instalar Ansible en macOS

```bash
brew install ansible
```

---

## Cómo correr el proyecto

### 1. Clonar el repositorio

```bash
git clone https://github.com/TU_USUARIO/Proyecto_Integrador_Infrastructura_de_Red.git
cd Proyecto_Integrador_Infrastructura_de_Red
```

### 2. Deshabilitar el DHCP interno de VirtualBox

Necesario para que el DHCP de la infraestructura funcione correctamente:

```bash
VBoxManage dhcpserver modify --network "HostInterfaceNetworking-vboxnet0" --disable
```

### 3. Levantar la infraestructura

```bash
vagrant up
```

Vagrant levanta los servidores en orden: DNS → DHCP → LDAP → SFTP. Cada uno se provisiona automáticamente con Ansible.

### 4. Verificar que todo funciona

```bash
# Verificar IPs asignadas por DHCP
vagrant ssh servidor-ldap -c "ip a show enp0s8"
vagrant ssh sftp_server -c "ip a show enp0s8"

# Verificar resolución DNS
vagrant ssh dns_server -c "dig auth.luthor.corp"
vagrant ssh dns_server -c "dig sftp.luthor.corp"

# Verificar leases del DHCP
vagrant ssh servidor-dhcp -c "cat /var/lib/dhcpd/dhcpd.leases"
```

---

## Estructura del proyecto

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

## Dominio

`luthor.corp`

| Nombre | Resuelve a |
|---|---|
| `ns.luthor.corp` | 192.168.58.2 |
| `auth.luthor.corp` | IP dinámica del servidor LDAP |
| `sftp.luthor.corp` | IP dinámica del servidor SFTP |

---

## Usuarios LDAP

Los usuarios se crean automáticamente al provisionar. Están organizados en OUs dentro de `dc=luthor,dc=corp`:

| OU | Grupos | Usuarios |
|---|---|---|
| `ou=Users` | — | UserQA0-2, Useradministracion0-4, etc. |
| `ou=Groups` | soporte, desarrollo, administracion, rr-hh, QA, SFTPUsers | — |
| `ou=Machines` | — | — |
| `ou=Service` | — | servicioUser |

Contraseña por defecto de administrador LDAP: `1234`

---

## Notas

- El DHCP de VirtualBox debe estar deshabilitado antes de correr `vagrant up`, de lo contrario LDAP y SFTP pueden recibir IPs incorrectas.
- La clave TSIG se genera automáticamente en el servidor DNS y el DHCP la obtiene vía Ansible. No es necesario ningún paso manual.
- El cliente Ubuntu (pendiente de implementación) se levantará como quinta VM con `vagrant up` una vez agregado al Vagrantfile.
