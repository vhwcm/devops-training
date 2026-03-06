#!/bin/bash
# Inicia o servidor Node.js em background
nohup node /opt/nodeapp/server.js > /var/log/nodeapp.log 2>&1 &
sleep 2
exit 0
