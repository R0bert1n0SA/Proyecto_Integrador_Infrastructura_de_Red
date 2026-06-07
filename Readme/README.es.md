# Proyecto Integrador — Infraestructura de Red

Infraestructura de red completa virtualizada con Vagrant, VirtualBox y Ansible. Incluye DNS autoritativo, DHCP con DNS dinámico (DDNS), directorio LDAP, servidor SFTP con jaula chroot, cliente Ubuntu con autenticación centralizada y monitoreo completo con Prometheus y Grafana.

---

## Tecnologías utilizadas

![Vagrant](https://img.shields.io/badge/Vagrant-1868F2?style=flat&logo=vagrant&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-183A61?style=flat&logo=virtualbox&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu_22.04-E95420?style=flat&logo=ubuntu&logoColor=white)

| Categoría | Tecnología |
|---|---|
| Virtualización | Vagrant + VirtualBox |
| Automatización | Ansible |
| DNS | BIND9 + DDNS + TSIG |
| DHCP | ISC DHCP |
| Directorio | OpenLDAP + Samba schema |
| Autenticación | PAM + nslcd + libpam-ldapd |
| Transferencia | OpenSSH (SFTP) + chroot |
| Contenedores | Docker + Docker Compose |
| Monitoreo | Prometheus + Grafana + Alertmanager |
| Métricas | Node Exporter |

---

## Arquitectura

<img src="https://github.com/user-attachments/assets/40342574-188c-43bf-bf52-6cce153c45ac" width="800">

## Grafana

<img width="1361" height="623" alt="Image" src="https://github.com/user-attachments/assets/e174c583-711f-4372-acd1-4f7b301a8d77" />


### Servidores

| Servidor | IP | Rol |
|---|---|---|
| DNS | 192.168.58.2 (fija) | BIND9 autoritativo para `luthor.corp` |
| DHCP | 192.168.58.3 (fija) | ISC DHCP + DDNS hacia el DNS |
| Monitoreo | 192.168.58.4 (fija) | Docker: Prometheus + Grafana + Alertmanager |
| LDAP | dinámica vía DHCP | OpenLDAP + Samba schema |
| SFTP | dinámica vía DHCP | OpenSSH con jaula chroot + nslcd |
| Cliente | dinámica vía DHCP | Ubuntu Desktop, auth LDAP |

---

## Decisiones de diseño

### DDNS en lugar de IP fija para LDAP y SFTP

La práctica estándar indica que los servidores deberían tener IP fija. En este proyecto se decidió usar DHCP con reservas por MAC + DDNS para demostrar cómo funciona la actualización dinámica del DNS. El DNS, el DHCP y el servidor de monitoreo sí mantienen IP fija ya que son la base de la infraestructura.

El DHCP autentica sus actualizaciones al DNS mediante **TSIG** (Transaction Signature con HMAC-SHA256), garantizando que solo el DHCP autorizado puede modificar los registros DNS.

### OpenLDAP sobre Active Directory

Se eligió OpenLDAP para mantener un entorno 100% Linux, sin dependencias de Windows. OpenLDAP es prácticamente un estándar en infraestructuras Linux y permite integración nativa con PAM, NSS y Samba.

### SFTP con jaula chroot

El servidor SFTP autentica usuarios contra LDAP mediante nslcd. Los usuarios del grupo `SFTPUsers` quedan enjaulados en `/srv/Chroot` con directorios `upload` y `download`. El grupo se sincroniza automáticamente desde LDAP mediante un script que corre vía cron.

### Monitoreo con Docker

El servidor de monitoreo corre Prometheus, Grafana y Alertmanager dentro de contenedores Docker. Cada VM de la infraestructura tiene Node Exporter instalado directamente, que expone métricas de CPU, RAM, disco y red en el puerto 9100. Prometheus las recolecta cada 15 segundos y Grafana las visualiza en dashboards. Usar Docker para el stack de monitoreo permite que si la VM se recrea, todo el entorno se levanta con un solo `docker compose up`.

### Cliente Ubuntu 

El cliente se levanta como VM con Ubuntu  Se autentica contra LDAP, resuelve nombres vía el DNS propio de la infraestructura (`auth.luthor.corp`, `sftp.luthor.corp`) y accede al SFTP con sus credenciales LDAP.

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

### Instalar Ansible en Windows

En Windows, Ansible no corre nativamente. La forma recomendada es usar **WSL2** (Windows Subsystem for Linux):

**1. Habilitar WSL2**
```powershell
# Ejecutar en PowerShell como Administrador
wsl --install
# Reiniciar el equipo cuando se solicite
```

**2. Instalar Ubuntu desde la Microsoft Store**

Buscá "Ubuntu 22.04" en la Microsoft Store e instalalo.

**3. Dentro de WSL2, instalar Ansible**
```bash
sudo apt update
sudo apt install -y ansible
```

**4. Instalar VirtualBox y Vagrant en Windows** (los instaladores normales para Windows)

**5. Configurar Vagrant para usar WSL2**
```bash
# Dentro de WSL2
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"
```

> **Nota:** Todos los comandos `vagrant` se ejecutan desde la terminal de WSL2, no desde PowerShell ni CMD.

---

## Cómo correr el proyecto

### 1. Clonar el repositorio

```bash
git clone https://github.com/R0bert1n0SA/Proyecto_Integrador_Infrastructura_de_Red.git
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
Vagrant levanta los servidores en orden: DNS → DHCP → Monitoreo → LDAP → SFTP → Cliente. Cada uno se provisiona automáticamente con Ansible.
 
> **Tiempo estimado:** entre 15 y 25 minutos dependiendo de la velocidad de descarga de las boxes y del hardware del host.


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

# Verificar contenedores de monitoreo
vagrant ssh servidor-monitoreo -c "docker compose -f /opt/monitoreo/docker-compose.yml ps"
```
### 5. Verificar el estado de los targets de Prometheus
 
Para ver si todos los exporters están siendo scrapeados correctamente, instalar `jq` (solo la primera vez) y ejecutar:
 
```bash
sudo apt install -y jq
 
curl -s http://192.168.58.4:9090/api/v1/targets | jq -r '
  ["SERVICIO", "ENDPOINT", "ESTADO", "ERROR"],
  ["--------", "--------", "------", "-----"],
  (.data.activeTargets[] | [
    .labels.job,
    .discoveredLabels.__address__,
    (.health | ascii_upcase),
    (if .lastError == "" then "Ninguno" else .lastError | split(":") | last | ltrimstr(" ") end)
  ]) | @tsv' | column -t -s $'\t'
```
 
La salida muestra una tabla con el nombre del servicio, su endpoint, el estado (`UP` o `DOWN`) y el error si lo hay.



### 6. Acceder al monitoreo

| Servicio | URL | Usuario | Contraseña |
|---|---|---|---|
| Grafana | http://192.168.58.4:3000 | admin | admin123 |
| Prometheus | http://192.168.58.4:9090 | — | — |
| Alertmanager | http://192.168.58.4:9093 | — | — |


## Reprovisionar un servidor individual
 
Si necesitás reprovisionar solo uno de los servidores sin recrear toda la infraestructura:
 
```bash
# Reprovisionar solo el servidor DNS
vagrant provision dns_server
 
# Reprovisionar solo el servidor LDAP
vagrant provision servidor-ldap
 
# Reprovisionar solo el servidor SFTP
vagrant provision sftp_server
 
# Reprovisionar solo el servidor de monitoreo
vagrant provision servidor-monitoreo
```
 
---

## Estructura del proyecto

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
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── 02-InstalarDependencias.yml
    │   │   └── 03-GenerarTSIG.yml
    │   ├── templates/
    │   │   ├── named.conf.options.j2
    │   │   ├── named.conf.local.j2
    │   │   ├── db.luthor.corp.j2
    │   │   └── db.58.168.192.j2
    │   └── vars/main.yml
    ├── dhcp/
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── 02-ObtenerTSIG.yml
    │   │   └── 03-Instalar-DHCP.yml
    │   ├── templates/
    │   │   ├── dhcpd_conf.j2
    │   │   └── isc-dhcp-server.j2
    │   └── vars/main.yml
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
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── 02-CopiarPlantillas.yml
    │   │   ├── 03-slapd.yml
    │   │   ├── 04-samba.yml
    │   │   ├── 05-Crear-Elementos-LDAP.yml
    │   │   ├── 07-ModoAnonimo-ACL.yml
    │   │   └── 08-SFTPUsers-Group.yml
    │   ├── files/
    │   │   ├── Crear.sh
    │   │   ├── ActualizarSFTP.sh
    │   │   ├── userPlantilla.ldif
    │   │   ├── groupPlantilla.ldif
    │   │   └── ouPlantilla.ldif
    │   ├── templates/
    │   │   ├── smb.conf.j2
    │   │   └── BannedUsers.txt.j2
    │   └── vars/main.yml
    ├── sftp-ssh/
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
    │   └── vars/main.yml
    └── cliente/
        ├── tasks/
        │   ├── main.yml
        │   └── 03-Config-PAM.yml
        └── vars/main.yml
```

---

## Dominio

`luthor.corp`

| Nombre | Resuelve a |
|---|---|
| `ns.luthor.corp` | 192.168.58.2 |
| `monitor.luthor.corp` | 192.168.58.4 |
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


## Troubleshooting
 
### LDAP o SFTP no reciben IP del DHCP
 
Verificar que el DHCP de VirtualBox esté deshabilitado antes de correr `vagrant up`:
 
```bash
VBoxManage dhcpserver modify --network "HostInterfaceNetworking-vboxnet0" --disable
```
 
Si las VMs ya están corriendo con IP incorrecta, destruirlas y volver a levantarlas:
 
```bash
vagrant destroy servidor-ldap -f && vagrant up servidor-ldap
vagrant destroy sftp_server -f && vagrant up sftp_server
```
 
### `vagrant up` falla a mitad del provisionamiento
 
Ansible es idempotente, se puede volver a ejecutar el provisionamiento sin problema:
 
```bash
vagrant provision <nombre-del-servidor>
```
 
Si el fallo es en la VM del cliente (que usa Ubuntu Bionic y puede tardar más), probar:
 
```bash
vagrant reload cliente --provision
```
 
### Los targets de Prometheus aparecen como DOWN
 
Verificar que Node Exporter esté activo en el servidor afectado:
 
```bash
vagrant ssh <nombre-del-servidor> -c "systemctl status node_exporter"
```
 
Si el servicio está caído, reiniciarlo:
 
```bash
vagrant ssh <nombre-del-servidor> -c "sudo systemctl restart node_exporter"
```
 
### Autenticación LDAP no funciona en el cliente
 
Verificar que nslcd esté corriendo y que el servidor LDAP sea alcanzable:
 
```bash
vagrant ssh cliente -c "systemctl status nslcd"
vagrant ssh cliente -c "getent passwd | grep User"
```
---

## Notas

- El DHCP de VirtualBox debe estar deshabilitado antes de correr `vagrant up`, de lo contrario LDAP y SFTP pueden recibir IPs incorrectas.
- La clave TSIG se genera automáticamente en el servidor DNS y el DHCP la obtiene vía Ansible. No es necesario ningún paso manual.
- En Windows se requiere WSL2 para correr Ansible. Ver sección de requisitos.
