#!/bin/bash
# ==============================================================================
# Script de Automação Replicável - Bloco 4: Servidor de E-mail (Postfix + Dovecot)
# Executar no Servidor de E-mail (172.16.0.2)
# Domínio: g07rc2.com.br
# ==============================================================================

set -e

DOMAIN="g07rc2.com.br"
IP_DNS="172.16.0.1"

echo "[1/6] Configurando DNS resolver local para usar o DNS do grupo..."
sudo cat <<EOF | sudo tee /etc/resolv.conf
nameserver $IP_DNS
search $DOMAIN
EOF

echo "[2/6] Instalando Postfix, Dovecot e utilitários..."
# Pré-configuração de variáveis do debconf para instalação silenciosa do Postfix
sudo debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

sudo apt update
sudo apt install -y postfix dovecot-imapd dovecot-core mailutils openssl

echo "[3/6] Gerando certificados TLS para serviços de e-mail..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/mail-selfsigned.key \
  -out /etc/ssl/certs/mail-selfsigned.crt \
  -subj "/C=BR/ST=RS/L=Passo Fundo/O=IFSUL/OU=RC2/CN=mail.$DOMAIN"

echo "[4/6] Configurando o Postfix (SMTP / Submission com Autenticação)..."

# Formato Maildir por utilizador
sudo postconf -e "home_mailbox = Maildir/"
sudo postconf -e "myhostname = mail.$DOMAIN"
sudo postconf -e "mydomain = $DOMAIN"
sudo postconf -e "myorigin = /etc/mailname"
sudo postconf -e "mydestination = \$myhostname, $DOMAIN, mail.$DOMAIN, localhost.$DOMAIN, localhost"
sudo postconf -e "mynetworks = 127.0.0.0/8 [::1]/128 172.16.0.0/16"

# Segurança TLS no Postfix
sudo postconf -e "smtpd_tls_cert_file = /etc/ssl/certs/mail-selfsigned.crt"
sudo postconf -e "smtpd_tls_key_file = /etc/ssl/private/mail-selfsigned.key"
sudo postconf -e "smtpd_tls_security_level = may"

# Autenticação SASL via Dovecot no Postfix
sudo postconf -e "smtpd_sasl_type = dovecot"
sudo postconf -e "smtpd_sasl_path = private/auth"
sudo postconf -e "smtpd_sasl_auth_enable = yes"
sudo postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination"

# Ativa a porta 587 (Submission / SMTP Autenticado) no /etc/postfix/master.cf
sudo cat <<EOF | sudo tee -a /etc/postfix/master.cf
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
EOF

echo "[5/6] Configurando o Dovecot (IMAP + TLS + Auth SASL)..."

# 10-mail.conf - Formato Maildir
sudo sed -i 's|^mail_location =.*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf

# 10-ssl.conf - Certificados TLS
sudo sed -i 's|^ssl =.*|ssl = required|' /etc/dovecot/conf.d/10-ssl.conf
sudo sed -i 's|^ssl_cert =.*|ssl_cert = </etc/ssl/certs/mail-selfsigned.crt|' /etc/dovecot/conf.d/10-ssl.conf
sudo sed -i 's|^ssl_key =.*|ssl_key = </etc/ssl/private/mail-selfsigned.key|' /etc/dovecot/conf.d/10-ssl.conf

# 10-master.conf - Socket de Autenticação SASL para o Postfix
sudo cat <<EOF | sudo tee /etc/dovecot/conf.d/10-master.conf
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

# Permite autenticação com texto simples sobre SSL/TLS
sudo sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf

echo "[6/6] Criando contas de e-mail de teste (alice e bob)..."

# Cria utilizadores do sistema para receberem e-mails
sudo useradd -m -s /bin/bash alice || true
echo "alice:senha123" | sudo chpasswd
sudo mkdir -p /home/alice/Maildir && sudo chown -R alice:alice /home/alice/Maildir

sudo useradd -m -s /bin/bash bob || true
echo "bob:senha123" | sudo chpasswd
sudo mkdir -p /home/bob/Maildir && sudo chown -R bob:bob /home/bob/Maildir

# Reinicia e ativa os serviços
sudo systemctl restart postfix dovecot
sudo systemctl enable postfix dovecot

echo "=============================================================================="
echo " Concluído! Servidor de E-mail (SMTP / IMAP TLS) configurado com sucesso."
echo " Contas criadas: alice@$DOMAIN e bob@$DOMAIN (Senha: senha123)"
echo "=============================================================================="