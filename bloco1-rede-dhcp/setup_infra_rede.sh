!/bin/bash
# ==============================================================================
# Script de Automação - Bloco 1: Rede, NAT/Roteamento e DHCP
# Domínio: g07rc2.com.br
# ==============================================================================

set -e # Interrompe a execução em caso de qualquer erro

IF_WAN="eth0"
IF_LAN="eth1"
IP_LAN="172.16.0.1"
NETMASK="255.255.0.0"
NETMASK_CIDR="16"

echo "[1/5] Atualizando pacotes e instalando dependências..."
sudo apt update
sudo apt install -y isc-dhcp-server iptables-persistent net-tools

echo "[2/5] Configurando Interfaces de Rede (/etc/network/interfaces)..."
sudo cat <<EOF | sudo tee /etc/network/interfaces
auto lo
iface lo inet loopback

auto $IF_WAN
iface $IF_WAN inet dhcp

auto $IF_LAN
iface $IF_LAN inet static
    address $IP_LAN
    netmask $NETMASK
EOF

# Aplica as configurações de interface
sudo systemctl restart networking || true

echo "[3/5] Habilitando Roteamento (IP Forwarding) e Regras NAT (iptables)..."
# Ativa sysctl permanentemente
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -w net.ipv4.ip_forward=1

# Limpa regras anteriores de NAT/FORWARD
sudo iptables -F
sudo iptables -t nat -F

# Aplica NAT e Regras de Encaminhamento
sudo iptables -t nat -A POSTROUTING -o $IF_WAN -j MASQUERADE
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i $IF_LAN -o $IF_WAN -j ACCEPT

# Salva regras para persistir após reinicialização do servidor
sudo netfilter-persistent save

echo "[4/5] Configurando Servidor DHCP (isc-dhcp-server)..."
# Define interface de escuta
sudo sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"$IF_LAN\"/" /etc/default/isc-dhcp-server

# Configura arquivo principal do DHCP
sudo cat <<EOF | sudo tee /etc/dhcp/dhcpd.conf
option domain-name "g07rc2.com.br";
option domain-name-servers 172.16.0.1;

default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 172.16.0.0 netmask 255.255.0.0 {
  range 172.16.0.100 172.16.0.200;
  option routers 172.16.0.1;
  option subnet-mask 255.255.0.0;
  option broadcast-address 172.16.255.255;
}

# Reserva obrigatória por MAC
host cliente-estacao {
  hardware ethernet aa:bb:cc:dd:ee:01; # Substitua pelo MAC real da interface do cliente
  fixed-address 172.16.0.150;
}
EOF

echo "[5/5] Reiniciando e ativando serviços..."
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server

echo "=============================================================================="
echo " Concluído! O ambiente de Rede/NAT/DHCP foi configurado com sucesso."
echo "=============================================================================="