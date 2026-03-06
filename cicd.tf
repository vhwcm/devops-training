# ─────────────────────────────────────────────────────────────────
# CI/CD: CodePipeline + CodeDeploy
#   Source: S3 (nodeapp.zip)
#   Deploy: CodeDeploy → ASG de 3 instâncias Node.js
# ─────────────────────────────────────────────────────────────────

# ─── S3 para artefatos do pipeline ───────────────────────────────

resource "aws_s3_bucket" "artifacts" {
  bucket = "codepipeline-artifacts-nodeapp"
}

resource "aws_s3_bucket_versioning" "artifacts_versioning" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ─── IAM: CodeDeploy service role ────────────────────────────────

resource "aws_iam_role" "codedeploy_role" {
  name = "codedeploy_service_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# ─── CodeDeploy Application ──────────────────────────────────────

resource "aws_codedeploy_app" "node_app" {
  name             = "node-hello-world-app"
  compute_platform = "Server"
}

# ─── CodeDeploy Deployment Group (In-Place + ALB) ────────────────

resource "aws_codedeploy_deployment_group" "node_dg" {
  app_name               = aws_codedeploy_app.node_app.name
  deployment_group_name  = "node-hello-world-dg"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  # Vincula ao Auto Scaling Group
  autoscaling_groups = [aws_autoscaling_group.node_asg.name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  # Derruba do ALB antes do deploy e recoloca depois
  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.node_tg.name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# ─── IAM: CodePipeline service role ──────────────────────────────

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline_service_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject",
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
        ]
      },
      {
        Sid    = "CodeDeploy"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
        ]
        Resource = "*"
      },
    ]
  })
}

# ─── CodePipeline ─────────────────────────────────────────────────
# Estágio 1 – Source:  polling no bucket S3 aguardando nodeapp.zip
# Estágio 2 – Deploy:  CodeDeploy aplica no ASG via appspec.yml

resource "aws_codepipeline" "node_pipeline" {
  name     = "node-hello-world-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket             = aws_s3_bucket.artifacts.bucket
        S3ObjectKey          = "nodeapp.zip"
        PollForSourceChanges = "true"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.node_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.node_dg.deployment_group_name
      }
    }
  }
}

# ─── Outputs ─────────────────────────────────────────────────────

output "pipeline_name" {
  value       = aws_codepipeline.node_pipeline.name
  description = "Nome do pipeline"
}

output "codedeploy_app_name" {
  value       = aws_codedeploy_app.node_app.name
  description = "Nome da aplicação CodeDeploy"
}

output "artifacts_bucket" {
  value       = aws_s3_bucket.artifacts.bucket
  description = "Bucket S3 — faça upload de nodeapp.zip para disparar o pipeline"
}
