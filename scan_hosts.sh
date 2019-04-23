#!/bin/bash
hosts="hosts.txt"
scan="/tmp/scan.txt"
dhcp="alumnos.dhcp"
net="192.168.0.0/24"

function ejecutar() {
    pregunta="$1"
    func1="$2"
    func2="$3"
    #read -t 1 -n 10000 discard
    read -p "$pregunta" sn 
    case $sn in
        [Ss]* ) $func1; return 0;;
            * ) $func2; return 1;;
    esac
}

function grabar_ip() {
    echo "Grabando nodo $mac con ip $ip y nombre $name."
    echo $mac $ip $name >> hosts.txt
}

function asignar_ip() {
    read -p "Indica su ip:" ip
    grabar_ip
}

function poner_nombre() {
    read -p "Indica su nombre:" name
}

function generar_dhcp() {
    [ -e $dhcp ] && rm $dhcp
    exec 5<$hosts
    while read -u5 mac ip name
    do 
        cat >> $dhcp << EOF
host $name { 
    hardware ethernet $mac; 
    fixed-address $ip;
}
EOF
    done
}

function escanear() {
    fping -c 1 -g $net 2> /dev/null 1> /dev/null
    arp -n -H ether 2> /dev/null | grep ":" | sed -n '1!p' | awk '{print $1, $3}' > $scan
    touch -a $hosts
    exec 4<$scan
    while read -u4 ip mac
    do
        result=`grep -c "$mac" $hosts`
        if [ "$result" == "0" ]
        then 
            echo ""
            echo "Se ha encontrado nodo con mac:$mac. Buscando nombre..."
            name=`avahi-resolve --address $ip 2> /tmp/error | cut -f2`
            error=$(</tmp/error)
            if [ ! -z "$error" ]; then
                ejecutar "El nodo no tiene nombre. Quieres ponerle uno (s/n)?" poner_nombre
            else
                ejecutar "Nombre del nodo:${name}. Quieres cambiarle el nombre (s/n)?" poner_nombre
            fi
            if [ $? -eq 0 ]; then
                ejecutar "La ip actual es $ip. Quieres ponerle otra ip fija (s/n)?" preguntar_ip grabar_ip
            else
                echo "Nodo $mac no procesado."
            fi
            ejecutar "Dejar de procesar nodos (s/n)?" exit
        else
            echo "$mac esta definido en hosts.txt"
        fi 
    done
}


#Mientras se quiera seguir buscando:

while [ $? -eq 0 ]; do
    ejecutar "Quieres escanear la red para buscar hosts (s/n)?" escanear 
done

ejecutar "Quieres generar el archivo $dhcp (s/n)?" generar_dhcp 
