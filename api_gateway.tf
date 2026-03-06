# ─────────────────────────────────────────────────────────────────
# API Gateway → ALB → Cluster Node.js
# GET / → "hello world"
# ─────────────────────────────────────────────────────────────────

resource "aws_api_gateway_rest_api" "hello_api" {
  name        = "hello-world-api"
  description = "API Gateway para o cluster Node.js Hello World"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ─── Método GET na raiz (/) ──────────────────────────────────────

resource "aws_api_gateway_method" "get_root" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_rest_api.hello_api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

# ─── Integração HTTP_PROXY → ALB ─────────────────────────────────

resource "aws_api_gateway_integration" "alb_integration" {
  rest_api_id             = aws_api_gateway_rest_api.hello_api.id
  resource_id             = aws_api_gateway_rest_api.hello_api.root_resource_id
  http_method             = aws_api_gateway_method.get_root.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "http://${aws_lb.node_alb.dns_name}/"

  depends_on = [aws_lb_listener.node_listener]
}

# ─── Recurso proxy para caminhos adicionais ──────────────────────

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  parent_id   = aws_api_gateway_rest_api.hello_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.hello_api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${aws_lb.node_alb.dns_name}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  depends_on = [aws_lb_listener.node_listener]
}

# ─── Deploy e Stage ──────────────────────────────────────────────

resource "aws_api_gateway_deployment" "hello_deploy" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id

  depends_on = [
    aws_api_gateway_method.get_root,
    aws_api_gateway_integration.alb_integration,
    aws_api_gateway_method.proxy_any,
    aws_api_gateway_integration.proxy_integration,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  deployment_id = aws_api_gateway_deployment.hello_deploy.id
  stage_name    = "prod"

  tags = { Name = "hello-world-prod" }
}

# ─── Outputs ─────────────────────────────────────────────────────

output "api_gateway_id" {
  value       = aws_api_gateway_rest_api.hello_api.id
  description = "ID da REST API"
}

output "api_gateway_url" {
  value       = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.hello_api.id}/prod/_user_request_/"
  description = "URL LocalStack para testar: GET /"
}
