#!/bin/bash
# ==============================================================================
# Script de Automação Replicável - Bloco 3: Serviço Web Apache (HTTPS + Auth)
# Domínio: g07rc2.com.br
# ==============================================================================

set -e

DOMAIN_WWW="www.g07rc2.com.br"
DOMAIN_INTRA="intranet.g07rc2.com.br"
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"
WEB_ROOT="/var/www"

echo "[1/6] Instalando o Apache e módulos necessários..."
sudo apt update
sudo apt install -y apache2 apache2-utils openssl

echo "[2/6] Habilitando módulos do Apache (SSL, Rewrite, Headers)..."
sudo a2enmod ssl rewrite headers

echo "[3/6] Criando Certificado SSL Local (Autoridade Certificadora Local)..."
# Gera chave privada e certificado autoassinado/local válido para os domínios
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$KEY_DIR/g07rc2-selfsigned.key" \
  -out "$CERT_DIR/g07rc2-selfsigned.crt" \
  -subj "/C=BR/ST=RS/L=Passo Fundo/O=IFSUL/OU=RC2/CN=*.g07rc2.com.br"

echo "[4/6] Criando estrutura de diretórios e páginas HTML..."
sudo mkdir -p "$WEB_ROOT/www/html"
sudo mkdir -p "$WEB_ROOT/intranet/html"
sudo mkdir -p /etc/apache2/passwords

# Página inicial do site WWW
sudo cat <<EOF | sudo tee "$WEB_ROOT/www/html/index.html"
<!DOCTYPE html>
<html>
<head><title>Portal WWW - G07</title></head>
<body>
    <h1>Bem-vindo ao site publico www.g07rc2.com.br!</h1>
    <p>Servico Web Apache a funcionar sobre HTTPS seguro.</p>
</body>
</html>
EOF

# Página inicial da INTRANET
sudo cat <<EOF | sudo tee "$WEB_ROOT/intranet/html/index.html"
<!DOCTYPE html>
<html>
<head><title>Intranet - G07</title></head>
<body>
    <h1>Area Restrita da Intranet (intranet.g07rc2.com.br)</h1>
    <p>Acesso autorizado com sucesso via autenticacao Basic Auth.</p>
</body>
</html>
EOF

# Ajusta permissões dos diretórios Web
sudo chown -R www-data:www-data "$WEB_ROOT"

echo "[5/6] Configurando autenticação restrita para a Intranet..."
# Cria um utilizador 'admin' com a palavra-passe 'senha123' (Ajustar na demonstração)
sudo htpasswd -cb /etc/apache2/passwords/.htpasswd admin senha123

echo "[6/6] Criando VirtualHosts HTTPS e redirecionamentos HTTP -> HTTPS..."

# --- VirtualHost WWW ---
sudo cat <<EOF | sudo tee /etc/apache2/sites-available/www.g07rc2.com.br.conf
# Redirecionamento HTTP -> HTTPS
<VirtualHost *:80>
    ServerName $DOMAIN_WWW
    Redirect permanent / https://$DOMAIN_WWW/
</VirtualHost>

# Host Virtual HTTPS
<VirtualHost *:443>
    ServerName $DOMAIN_WWW
    DocumentRoot $WEB_ROOT/www/html

    SSLEngine on
    SSLCertificateFile $CERT_DIR/g07rc2-selfsigned.crt
    SSLCertificateKeyFile $KEY_DIR/g07rc2-selfsigned.key

    # Logs Separados (Requisito obrigatório)
    ErrorLog \${APACHE_LOG_DIR}/www_error.log
    CustomLog \${APACHE_LOG_DIR}/www_access.log combined
</VirtualHost>
EOF

# --- VirtualHost INTRANET ---
sudo cat <<EOF | sudo tee /etc/apache2/sites-available/intranet.g07rc2.com.br.conf
# Redirecionamento HTTP -> HTTPS
<VirtualHost *:80>
    ServerName $DOMAIN_INTRA
    Redirect permanent / https://$DOMAIN_INTRA/
</VirtualHost>

# Host Virtual HTTPS com Autenticação Restrita
<VirtualHost *:443>
    ServerName $DOMAIN_INTRA
    DocumentRoot $WEB_ROOT/intranet/html

    SSLEngine on
    SSLCertificateFile $CERT_DIR/g07rc2-selfsigned.crt
    SSLCertificateKeyFile $KEY_DIR/g07rc2-selfsigned.key

    <Directory "$WEB_ROOT/intranet/html">
        AuthType Basic
        AuthName "Acesso Restrito - Intranet G07"
        AuthUserFile /etc/apache2/passwords/.htpasswd
        Require valid-user
    </Directory>

    # Logs Separados (Requisito obrigatório)
    ErrorLog \${APACHE_LOG_DIR}/intranet_error.log
    CustomLog \${APACHE_LOG_DIR}/intranet_access.log combined
</VirtualHost>
EOF

# Ativa os novos VirtualHosts e desativa o default
sudo a2dissite 000-default.conf || true
sudo a2ensite www.g07rc2.com.br.conf
sudo a2ensite intranet.g07rc2.com.br.conf

# Valida a sintaxe da configuração do Apache e reinicia o serviço
sudo apachectl configtest
sudo systemctl restart apache2
sudo systemctl enable apache2

echo "=============================================================================="
echo " Concluido! Servico Web Apache configurado com HTTPS e Autenticacao."
echo "=============================================================================="