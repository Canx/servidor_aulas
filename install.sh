#!/bin/bash


destino=/etc/network/interfaces
temp=/tmp/fichero


echo ">> Configurando las interfaces de red"
cp -p $destino $destino.back
echo "   Copia realizada: $destino.back"


lista_interfaces=`ip link | awk -F: '$0 !~ "lo|vir|wl|dock|vmnet|^[^0-9]"{print $2;getline}'|sort`

echo "   Detectadas las siguientes interfaces"
for interface in $lista_interfaces
do
echo "     $interface"
done


########### CONFIGURACION TARJETA DE RED

touch $temp
echo "source /etc/network/interfaces.d/*">$temp
echo "">>$temp
echo "# The loopback network interface">>$temp
echo "auto lo">>$temp
echo "iface lo inet loopback">>$temp
echo "">>$temp

num_interface=0
for interface in $lista_interfaces
do
  if [ $num_interface -eq 0 ]; then
    wan=$interface
    echo "# WAN">>$temp
    echo "# The primary network interface">>$temp

    echo "   Vamos a configurar la tarjeta de red (WAN)"
    read -p "    Tipo configuracion (1: Estatica / 2: Dinamica) : " tipo

    echo "auto $interface">>$temp

    if [ "$tipo" -eq 1 ]; then

      echo "iface $interface inet static">>$temp
      read -p "Direccion IP (en rango 172.28.128.0/23): " ip
      echo "	address $ip">>$temp
      echo "	netmask 255.255.254.0">>$temp
      echo "	network 172.28.128.0">>$temp
      echo "	broadcast 172.28.129.255">>$temp
      echo "	gateway 172.28.128.1">>$temp
      echo "	dns-nameservers 172.27.111.5 172.27.111.6">>$temp
      echo "	dns-search local">>$temp
    else
      echo "iface $interface inet dhcp">>$temp
    fi

  else
    lan=$interface
    echo "">>$temp
    echo "# LAN">>$temp
    echo "# Interfaz de aula">>$temp
    echo "allow-hotplug $interface">>$temp
    echo "iface $interface inet static">>$temp
    echo "	address 192.168.0.1">>$temp
    echo "	netmask 255.255.255.0">>$temp
    echo "	network 192.168.0.0">>$temp
    echo "	broadcast 192.168.0.255">>$temp
    echo "	gateway 192.168.0.1">>$temp
    echo "	dns-nameservers 172.27.111.5 172.27.111.6">>$temp
    echo "	dns-search local">>$temp
  fi

  num_interface=$(expr $num_interface + 1)
done

cat $temp>$destino

echo "   Aplicando cambios de configuracion en tarjeta de red"

for interface in $lista_interfaces
do
  ip addr flush $interface 1>/dev/null
  ifdown $interface 1>/dev/null
  ifup $interface 1>/dev/null
done

systemctl restart networking.service 1>/dev/null
echo "<< Cambios aplicados"

########### FIN CONFIGURACION TARJETA DE RED




########### CONFIGURACION SERVICIO DHCP
echo ""

apt-get update 1>/dev/null

echo "   Configurando servicio DHCP ..."
apt-get install -y isc-dhcp-server 1>/dev/null

destino=/etc/dhcp/dhcpd.conf
echo "   Configurando $destino"

echo "   Realizando copia de seguridad $destino"
if [ -f $destino.back ]; then
  echo "   Copia realizada: $destino.back"
else
  cp -p $destino $destino.back
  echo "   Copia realizada: $destino.back"
fi

echo "ddns-update-style none;">$temp
echo "">>$temp
echo "default-lease-time 86400;	  ">>$temp
echo "max-lease-time 604800; ">>$temp
echo "">>$temp
echo "authoritative;">>$temp
echo "">>$temp
echo "log-facility local7;">>$temp
echo "">>$temp
echo "option domain-name-servers 192.168.0.1;">>$temp
echo "">>$temp
echo "subnet 192.168.0.0 netmask 255.255.255.0 {">>$temp
echo "  range 192.168.0.100 192.168.0.254;">>$temp
echo "  option routers 192.168.0.1;">>$temp
echo "}">>$temp
echo "">>$temp

cat $temp>$destino

sed -i -e "s/INTERFACES=\"\"/INTERFACES=\"$lan\"/g" /etc/default/isc-dhcp-server
echo "   Fichero /etc/default/isc-dhcp-server modificado"

echo "   Servicio DHCP configurado!"

########### FIN CONFIGURACION SERVICIO DHCP


########### CONFIGURACION SERVICIO DNS
echo ""

echo "   Configurando servicio DNS ..."
apt-get install -y bind9 1>/dev/null



destino=/etc/bind/named.conf.options
echo "   Configurando $destino"

echo "   Realizando copia de seguridad $destino"
if [ -f $destino.back ]; then
  echo "   Copia realizada: $destino.back"
else
  cp -p $destino $destino.back
  echo "   Copia realizada: $destino.back"
fi


echo "acl equipos{">$temp
echo "	192.168.0.0/24;">>$temp
echo "	localhost;">>$temp
echo "	localnets;">>$temp
echo "};">>$temp
echo "">>$temp
echo "options {">>$temp
echo ' 	directory "/var/cache/bind";'>>$temp
echo "">>$temp
echo "	recursion yes;">>$temp
echo "	allow-query { equipos; };">>$temp
echo "">>$temp
echo "	forwarders {">>$temp
echo "	  172.27.111.5;">>$temp
echo "	  172.27.111.6;">>$temp
echo "	};">>$temp
echo "	forward only;">>$temp
echo "">>$temp
echo "	dnssec-enable yes;">>$temp
echo "	dnssec-validation yes;">>$temp
echo "">>$temp
echo "	auth-nxdomain no;">>$temp
echo "	listen-on-v6 { 192.168.0.0/24; };">>$temp
echo "};">>$temp
echo "">>$temp


cat $temp>$destino



echo "   Servicio DNS configurado!"
########### FIN CONFIGURACION SERVICIO DNS


########### CONFIGURACION SERVICIO FTP
echo ""

echo "   Configurando servicio FTP ..."
apt-get install -y vsftpd 1>/dev/null

destino=/etc/vsftpd.conf
echo "   Configurando $destino"

echo "   Realizando copia de seguridad $destino"
if [ -f $destino.back ]; then
  echo "   Copia realizada: $destino.back"
else
  cp -p $destino $destino.back
  echo "   Copia realizada: $destino.back"
fi


echo "listen=NO">$temp
echo "listen_ipv6=YES">>$temp
echo "">>$temp
echo "anonymous_enable=YES">>$temp
echo "local_enable=YES">>$temp
echo "">>$temp
echo "write_enable=YES">>$temp
echo "local_umask=022">>$temp
echo "">>$temp
echo "dirmessage_enable=YES">>$temp
echo "">>$temp
echo "use_localtime=YES">>$temp
echo "">>$temp
echo "xferlog_enable=YES">>$temp
echo "">>$temp
echo "connect_from_port_20=YES">>$temp
echo "">>$temp
echo "ftpd_banner=Bienvenido al servidor ftp del aula">>$temp
echo "chroot_local_user=YES">>$temp
echo "secure_chroot_dir=/var/run/vsftpd/empty">>$temp
echo "pam_service_name=vsftpd">>$temp
echo "rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem">>$temp
echo "rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key">>$temp
echo "ssl_enable=NO">>$temp
echo "local_root=/var/ftp">>$temp
echo "anon_root=/var/ftp">>$temp

cat $temp>$destino


if id profesor >/dev/null 2>&1; then
  echo "   Usuario profesor existe en el sistema"
else
  echo "   Vamos a crear un usuario profesor para el servicio FTP"
  echo "   Debes introducir la contraseña del usuario"
  adduser profesor
fi
mkdir -p /var/ftp/descargas
chown profesor:profesor /var/ftp/descargas
chmod 775 /var/ftp/descargas

echo "   Servicio FTP configurado!"

########### FIN CONFIGURACION SERVICIO FTP

echo ""

## ENRUTAMIENTO
echo "   Configurando enrutamiento en el servidor (/etc/sysctl.conf)"

if cat /etc/sysctl.conf |grep "#net.ipv4.ip_forward">/dev/null 2>&1; then
#  echo "net.ipv4.ip_forward=1">>/etc/sysctl.conf
  sed -i -e 's/\#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  echo "   Hecho"
else
  echo "   Hecho"
fi


## IPTABLES
echo "   Configurando iptables"
rm -rf /etc/iptables.conf
iptables -F
iptables -t nat -F
iptables -A FORWARD -i $lan -j ACCEPT
iptables -A FORWARD -o $lan -j ACCEPT
iptables -t nat -A POSTROUTING -o $wan -j MASQUERADE
iptables-save>/etc/iptables.conf
echo "   Hecho"



## RC.LOCAL
destino=/etc/rc.local
echo "   Configurando $destino"

echo "   Realizando copia de seguridad $destino"
if [ -f $destino.back ]; then
  echo "   Copia realizada: $destino.back"
else
  cp -p $destino $destino.back
  echo "   Copia realizada: $destino.back"
fi

echo '#!/bin/sh -e'>$destino
echo "iptables-restore</etc/iptables.conf">>$destino
echo "exit 0">>$destino


echo "   Hecho"

## Instalación de netdata
echo "    Instalación de netdata"
bash <(curl -Ss https://my-netdata.io/kickstart.sh)

## Instalación de fireqos
echo "    Instalación de fireqos"
sudo add-apt-repository ppa:andvgal/firehol-bpo
sudo apt-get update
sudo apt-get install fireqos



###########################################################################################################################
echo ""
echo "-------------------------------------------"
echo ">>>> Configuracion del servidor finalizada!"
read -p "PULSA INTRO PARA REINICIAR : " tipo
reboot

