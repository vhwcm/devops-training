#!/bin/bash
set -e

# Atualiza o sistema
yum update -y

# Instala Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Cria diretório da aplicação
mkdir -p /opt/nodeapp

# Cria o server.js inicial (será sobrescrito pelo CodeDeploy nos deploys)
cat > /opt/nodeapp/server.js << 'ENDOFSCRIPT'
const http = require('http');

const hostname = '0.0.0.0';
const port = 8080;

const server = http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('hello world');
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
    }
});

server.listen(port, hostname, () => {
    console.log(`Server running at http://${hostname}:${port}/`);
});
ENDOFSCRIPT

# Inicia o servidor na inicialização
nohup node /opt/nodeapp/server.js > /var/log/nodeapp.log 2>&1 &

# Instala o agente do CodeDeploy
yum install -y ruby wget
cd /tmp
wget https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/install
chmod +x ./install
./install auto
service codedeploy-agent start
systemctl enable codedeploy-agent
