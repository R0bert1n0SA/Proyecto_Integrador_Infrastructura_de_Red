#!/bin/bash

# ==============================================================================
# Script: ActualizarSFTP.sh
# Descripción: Gestión automatizada de usuarios en el grupo LDAP 'SFTPUsers'.
#              Filtra usuarios baneados y sincroniza miembros mediante LDIF.
# 
# ==============================================================================

# --- Variables Globales y Configuración ---
FILE_Banned="/var/lib/BannedUsers.txt"
tempF=$(mktemp --suffix=.ldif)  # Archivo temporal para transacciones LDAP
mapfile -t baneados < "$FILE_Banned"
usuarios=()

# --- Funciones de Utilidad ---

# Realiza búsquedas en el servidor LDAP
# @param1: Base de búsqueda (DN relativo)
# @param2: Atributo a recuperar
Busqueda_LDAP(){
    local param1=$1
    local param2=$2
    ldapsearch -x -D "cn=admin,dc=luthor,dc=corp" -b "$param1,dc=luthor,dc=corp" "$param2" -w 1234
}

# Verifica la existencia de un grupo por su Common Name (cn)
# @return: 0 si existe, 32 si no se encuentra
Existe(){
    local nombre=$1
    local valor=($(Busqueda_LDAP "cn=$nombre,ou=Groups" "cn"))
    if [[ -z "$valor" ]]; then
        return 32
    else
        return 0
    fi
}

# Busca el siguiente GID (Group ID) disponible en el rango > 2000
Verificar_IDLibre(){
    local UIDs=($(Busqueda_LDAP "ou=Groups" "gidNumber"))
    # Filtra IDs mayores a 2000 y ordena numéricamente
    local usadas=($(printf "%s\n" "${UIDs[@]}" | awk '$1 > 2000' | sort -n))
    
    echo "IDs detectadas: ${UIDs[@]}"
    echo "IDs en uso (>2000): ${usadas[@]}"
    
    local ult=${usadas[-1]}    # Toma el último ID de la lista
    local gid=$((ult + 1))     # Incrementa para el nuevo grupo
    
    if [[ "$gid" < 2999 ]]; then
        echo -e "gidNumber: $gid" >> "$tempF"
    else
        echo "Error: Límite de GIDs alcanzado (máx 2999)"
    fi
}

# Escribe los miembros (memberUid) en el archivo LDIF actual
Cargar_Miembros(){
    for A in "${usuarios[@]}" ;do
        echo "memberUid: $A" >> "$tempF"
    done
}

# Genera las instrucciones de eliminación de miembros para ldapmodify
Eliminar_Miembros(){
    echo -e "-" >> "$tempF"
    echo -e "delete: memberUid" >> "$tempF"
    for E in "${DeleteUsers[@]}" ;do
        echo -e "memberUid: $E" >> "$tempF"
    done
}

# Lógica principal de comparación de usuarios
# @param1: "N" para creación de grupo nuevo, "M" para modificación de grupo existente
AgregarUsers(){
    local exist=$1
    local -a usersGrup=()
    local -a DeleteUsers=()
    local -a final=()
    
    if [[ "$exist" == "N" ]]; then
        # Caso: Grupo Nuevo. Filtra base contra baneados.
        mapfile -t usuarios < <(comm -23 <(printf "%s\n" "${usuariosbase[@]}" | sort -n) <(printf "%s\n" "${baneados[@]}" | sort -n))
        Cargar_Miembros
        return 0
    else
        # Caso: Modificación. Compara usuarios deseados vs actuales en LDAP.
        usersGrup=($(Busqueda_LDAP "cn=SFTPUsers,ou=Groups" "memberUid"))
        mapfile -t final < <(comm -23 <(printf "%s\n" "${usuariosbase[@]}" | sort -n) <(printf "%s\n" "${baneados[@]}" | sort -n))
        
        # Si la lista final coincide con la de LDAP, no hay cambios pendientes
        if [[ "${final[*]}" == "${usersGrup[*]}" ]]; then
            exit 0
        fi
        
        # Identifica usuarios nuevos y usuarios a eliminar
        mapfile -t usuarios < <(comm -23 <(printf "%s\n" "${final[@]}" | sort -n) <(printf "%s\n" "${usersGrup[@]}" | sort -n))
        mapfile -t DeleteUsers < <(comm -23 <(printf "%s\n" "${usersGrup[@]}" | sort -n) <(printf "%s\n" "${final[@]}" | sort -n))
        
        Cargar_Miembros
        if [[ "${#DeleteUsers[@]}" != 1 ]]; then
            Eliminar_Miembros
        fi
    fi
}

# --- Ejecución Principal (Main) ---

# 1. Obtener lista base de usuarios de la organización
usuariosbase=($(Busqueda_LDAP "ou=Users" "uid"))
echo -e "dn: cn=SFTPUsers,ou=Groups,dc=luthor,dc=corp" >> "$tempF"

# 2. Determinar si el grupo SFTPUsers debe crearse (ldapadd) o modificarse (ldapmodify)
if ! Existe "SFTPUsers" ; then
    # Preparar creación de grupo nuevo
    echo -e "objectClass: top\nobjectClass: posixGroup\ncn: SFTPUsers" >> "$tempF"
    Verificar_IDLibre
    AgregarUsers "N"
    /usr/bin/ldapadd -x -D "cn=admin,dc=luthor,dc=corp" -f "$tempF" -w 1234
else
    # Preparar modificación de grupo existente
    echo -e "changeType: modify" >> "$tempF"
    echo -e "add: memberUid" >> "$tempF"
    AgregarUsers "M"
    /usr/bin/ldapmodify -x -D "cn=admin,dc=luthor,dc=corp" -w 1234 -f "$tempF"
fi

# 3. Limpieza de archivos temporales
rm "$tempF"
