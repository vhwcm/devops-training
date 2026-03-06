#!/bin/bash
# Aguarda o servidor inicializar e valida a resposta
sleep 3
curl --silent --fail --retry 5 --retry-delay 3 http://localhost:8080/ | grep -q "hello world"
exit $?
