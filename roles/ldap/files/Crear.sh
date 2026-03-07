#!/bin/bash
# Uso: ./script.sh [tipo] [nombre/area] [cantidad (solo para usuarios)]
# Tipos: user, group, ou
set -x 
echo "Programa para crear ldif"
dirBase="/home/administrador-ldap"
PlantillaU="$dirBase/Plantillas/userPlantilla.ldif"
PlantillaG="$dirBase/Plantillas/groupPlantilla.ldif"
PlantillaO="$dirBase/Plantillas/ouPlantilla.ldif"
array=()
sambagen=$(sudo net getlocalsid 2>/dev/null | grep "^SID" | awk '{print $6}')

# Recibir argumentos
opcion=$1
Input1=$2
Input2=$3

# Archivo temporal para esta ejecución específica
TEMP_LDIF=$(mktemp --suffix=.ldif)

Buscar(){
    local param1=$1
    local param2=$2
    local param3=$3
    ldapsearch -x -D "cn=admin,dc=luthor,dc=corp" -b "$param1,dc=luthor,dc=corp" "$param3" -w  "1234" |grep "$param2" | awk '{print $2}'
}

Validador(){
    local valor=$1
    local suma=$2
    local final=$3
    if [[ ${#array[@]} -eq 0 ]]; then
        array=($valor)
    fi
    if (( ${array[-1]} + $suma > $final )); then
        echo " No hay espacio "
        exit 20
    fi
}

Groups(){
    local nombre=$1
    local gid=0
    array=($(Buscar "ou=Groups" "gidNumber: *" "gidNumber"| awk '$1 >= 2000' | sort  -n))
    Validador 1999 1 2999
    gid=$(( ${array[-1]} + 1 ))
    rid=$(( gid * 2 + 1000 ))
    sambaid="${sambagen}-${rid}"
    sed -e "s|{id-grupo}|$nombre|g" \
           -e "s|{grupo-id}|$gid|g" \
           -e "s|{sid}|$sambaid|g"  "$PlantillaG" >> "$TEMP_LDIF"

    ldapadd -x -D "cn=admin,dc=luthor,dc=corp"  -w "1234"  -f "$TEMP_LDIF" 

# Limpiamos el temporal
    rm -f "$TEMP_LDIF"
}

SambaGroupsEsp(){
    local sidAdmin="${sambagen}-512"
    local sidUsers="${sambagen}-513"
    cat <<EOF >> "$TEMP_LDIF"
dn: cn=Domain Admins,ou=Groups,dc=luthor,dc=corp
objectClass: top
objectClass: posixGroup
objectClass: sambaGroupMapping
cn: Domain Admins
gidNumber: 512
sambaSID: $sidAdmin
sambaGroupType: 2
displayName: Domain Admins

dn: cn=Domain Users,ou=Groups,dc=luthor,dc=corp
objectClass: top
objectClass: posixGroup
objectClass: sambaGroupMapping
cn: Domain Users
gidNumber: 513
sambaSID: $sidUsers
sambaGroupType: 2
displayName: Domain Users
EOF

    ldapadd -x -D "cn=admin,dc=luthor,dc=corp" -w "1234" -f "$TEMP_LDIF"
    rm -f "$TEMP_LDIF"
}

Users(){
    local Area=$1
    local Cantidad=$2
    local gid=$(Buscar "ou=Groups" "gidNumber: *" "cn=$Area")
    array=($(Buscar "ou=Users" "uidNumber: *" "uidNumber" | awk '$1 >= 3000' | sort  -n))
    Validador 2999 "$Cantidad" 3999
    if [[ -z "$gid" ]]; then
        echo "No existe el grupo"
        exit 20
    fi
    for (( i=0; i<$Cantidad; i++ )); do
        SetearValores "$(( ${array[${#array[@]}-1]} + 1 ))" "$Area" "$gid"
    done
    echo "$Cantidad usuarios generados para $Area"
    ldapadd -x -D "cn=admin,dc=luthor,dc=corp"  -w "1234"  -f "$TEMP_LDIF" 
    
    # Limpiamos el temporal
    rm -f "$TEMP_LDIF"
}

SetearValores(){
    local ult=$1
    local sect=$2
    local Ugid=$3
    local indenU="User$sect$i"
    local nombreC="Nomb$sect$i Apell$sect$i"
    local apellido="Apell$sect$i"
    local NumberU=$(( ult + i ))
    local home="/home/User$sect$i"
    local shell="/bin/bash"
    local mail="User$sect$i@luthor.corp"
    local UPass="User$i"
    local gidN=$Ugid
    local sambaLDS=$(date +%s)
    local sambasid="${sambagen}-${NumberU}"
    local sambantp=$(mkntpwd "$UPass")

    sed -e "s|{id-user}|$indenU|g" \
        -e "s|{nombre-completo}|$nombreC|g" \
        -e "s|{apellido}|$apellido|g" \
        -e "s|{number-User}|$NumberU|g" \
        -e "s|{home}|$home|g" \
        -e "s|{shell}|$shell|g" \
        -e "s|{mail}|$mail|g" \
        -e "s|{password}|$UPass|g" \
        -e "s|{grupo-id}|$gidN|g" \
        -e "s|{samba3}|$sambaLDS|g" \
        -e "s|{samba1}|$sambasid|g" \
        -e "s|{samba2}|$sambantp|g" "$PlantillaU" >> "$TEMP_LDIF"

    echo "" >> "$TEMP_LDIF"
}

case "$opcion" in
    1)
        Users "$Input1" "$Input2"
        ;;
    2)
        Groups "$Input1"
        ;;
    3)
        SambaGroupsEsp 
        ;;
    4)
        sed -e "s/{ou-name}/$Input1/g" "$PlantillaO" >> "$TEMP_LDIF"
        ldapadd -x -D "cn=admin,dc=luthor,dc=corp" -w "1234" -f "$TEMP_LDIF"
        rm -f "$TEMP_LDIF"
        ;;
    *)
        echo "Opcion invalida o faltan argumentos"
        echo "Uso: $0 {1|2|3} [Nombre/Area] [Cantidad]"
        exit 1
        ;;
esac
