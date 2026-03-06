#!/bin/bash
# Para o processo do servidor Node.js, se estiver rodando
pkill -f "node /opt/nodeapp/server.js" 2>/dev/null || true
exit 0
