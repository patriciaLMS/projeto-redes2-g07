!/bin/bash
# ==============================================================================
# Script de Automação Replicável - Bloco 2: Servidor DNS BIND9
# Domínio: g07rc2.com.br
# ==============================================================================

set -e

DOMAIN="g07rc2.com.br"
REV_ZONE="0.16.172.in-addr.arpa"
IP_INFRA="172.16.0.1"
IP_MAIL="172.16.0.2"

echo "[1/4] Instalando BIND9 e ferramentas de verificação..."
sudo apt update
sudo apt install -y bind9 bind9utils bind9-doc dnsutils

echo "[2/4] Configurando opções globais do BIND9 (/etc/bind/named.conf.options)..."
sudo cat <<EOF | sudo tee /etc/bind/named.conf.options
options {
        directory "/var/cache/bind";

        # Redirecionadores para consultas externas (WAN)
        forwarders {
                8.8.8.8;
                8.8.4.4;
        };

        dnssec-validation auto;
        listen-on-v4 { any; };
        listen-on-v6 { any; };
        allow-query { any; };
};
EOF

echo "[3/4] Declarando Zonas Direta e Reversa (/etc/bind/named.conf.local)..."
sudo cat <<EOF | sudo tee /etc/bind/named.conf.local
// Zona Direta
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.g07rc2.com.br";
};

// Zona Reversa (Rede 172.16.0.0/16)
zone "$REV_ZONE" {
    type master;
    file "/etc/bind/db.172.16";
};
EOF

echo "[4/4] Criando arquivos de Zona..."

# --- 4.1 Arquivo de Zona Direta ---
sudo cat <<EOF | sudo tee /etc/bind/db.g07rc2.com.br
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. root.$DOMAIN. (
                              2026110901 ; Serial (AAAA MM DD VV)
                                  604800 ; Refresh
                                   86400 ; Retry
                                 2419200 ; Expire
                                  604800 ) ; Negative Cache TTL
;
; Servidor de Nomes Autoritativo (NS)
@       IN      NS      ns1.$DOMAIN.

; Registro MX (Requisito obrigatório para e-mail)
@       IN      MX  10  mail.$DOMAIN.

; Registros A (Mapeamento Nome -> IP)
ns1       IN      A       $IP_INFRA
@         IN      A       $IP_INFRA
www       IN      A       $IP_INFRA
intranet  IN      A       $IP_INFRA
mail      IN      A       $IP_MAIL
EOF

# --- 4.2 Arquivo de Zona Reversa ---
sudo cat <<EOF | sudo tee /etc/bind/db.172.16
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. root.$DOMAIN. (
                              2026110901 ; Serial
                                  604800 ; Refresh
                                   86400 ; Retry
                                 2419200 ; Expire
                                  604800 ) ; Negative Cache TTL
;
; Servidor de Nomes
@       IN      NS      ns1.$DOMAIN.

; Registros PTR (Mapeamento IP -> Nome)
1.0     IN      PTR     ns1.$DOMAIN.
1.0     IN      PTR     www.$DOMAIN.
1.0     IN      PTR     intranet.$DOMAIN.
2.0     IN      PTR     mail.$DOMAIN.
EOF

echo "[5/5] Validando configurações e reiniciando o BIND9..."

# Testes de sintaxe dos arquivos de configuração do BIND9
sudo named-checkconf
sudo named-checkzone $DOMAIN /etc/bind/db.g07rc2.com.br
sudo named-checkzone $REV_ZONE /etc/bind/db.172.16

# Reinicia e habilita o serviço na inicialização do sistema
sudo systemctl restart bind9
sudo systemctl enable bind9

echo "=============================================================================="
echo " Concluído! Servidor DNS BIND9 configurado com sucesso para $DOMAIN."
echo "=============================================================================="