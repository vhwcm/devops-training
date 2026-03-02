# LocalStack DevOps Training Project

Este projeto é um ambiente de treinamento focado em práticas de DevOps, utilizando **LocalStack** para emular serviços da AWS localmente, **Terraform** para Infraestrutura como Código (IaC), **Docker** para containerização e **GitHub Actions** para CI/CD.

## 🚀 Tecnologias Utilizadas

- **LocalStack**: Emulação de serviços AWS (S3, Lambda, DynamoDB, IAM, STS) para desenvolvimento e testes locais sem custos.
- **Terraform**: Gerenciamento automatizado da infraestrutura AWS.
- **Python (3.11)**: Linguagem utilizada para a função Lambda, utilizando a biblioteca `boto3`.
- **Node.js**: Servidor HTTP simples rodando em um container Docker.
- **Docker**: Containerização da aplicação Node.js.
- **GitHub Actions**: Pipeline de CI/CD para automação de build e push da imagem Docker.

## 🏗️ Arquitetura do Sistema

O projeto implementa uma arquitetura orientada a eventos (Event-Driven):

1.  **S3 Bucket (`bucket-entrada-python`)**: Atua como o ponto de entrada. Quando um arquivo é carregado, ele dispara um evento.
2.  **AWS Lambda (`logger_s3_to_dynamo`)**: A função Python é acionada automaticamente pelo evento do S3.
3.  **DynamoDB (`LogsArquivos`)**: A Lambda extrai metadados do arquivo (nome, bucket, tamanho) e os registra nesta tabela.
4.  **Servidor Node.js**: Um serviço separado rodando via Docker que fornece uma resposta HTTP simples (`hello-world`), representando um componente de aplicação frontend ou API.

## 📂 Estrutura de Arquivos

```text
.
├── .github/workflows/      # Definições de CI/CD (GitHub Actions)
│   └── deploy-image.yml    # Pipeline para build e push da imagem Docker
├── localstack_data/        # Dados persistentes do LocalStack
├── dockerfile              # Instruções para criação da imagem do servidor Node.js
├── index.py                # Código-fonte da função AWS Lambda (Python)
├── main.tf                 # Configurações de infraestrutura do Terraform
├── server.js               # Código-fonte do servidor Node.js
├── function.zip            # Pacote da função Lambda para deploy
└── terraform.tfstate       # Estado atual da infraestrutura gerenciada pelo Terraform
```

## 🛠️ Como Executar

### Pré-requisitos
- Docker & Docker Compose
- Terraform
- AWS CLI (opcional, para testes manuais)

### Passo a Passo

1.  **Iniciar o LocalStack**:
    Certifique-se de que o LocalStack está rodando (via Docker Compose ou CLI).

2.  **Provisionar Infraestrutura**:
    ```bash
    terraform init
    terraform apply -auto-approve
    ```

3.  **Subir o Servidor Node.js**:
    ```bash
    docker build -t server-node .
    docker run -p 8080:8080 server-node
    ```

4.  **Testar o Fluxo**:
    Faça o upload de um arquivo para o bucket S3 via AWS CLI apontando para o LocalStack:
    ```bash
    aws --endpoint-url=http://localhost:4566 s3 cp arquivo.txt s3://bucket-entrada-python/
    ```
    Verifique os logs da Lambda e a tabela no DynamoDB para confirmar o processamento.

---
Este projeto demonstra a integração entre desenvolvimento de software e infraestrutura moderna.
