/*
Relaciones:
package_file
  → filebase64sha256
  → Terraform detecta una nueva versión del código

IAM role
  → aws_lambda_function.role
  → credenciales temporales durante la ejecución

CloudWatch Log Group
  ← logs producidos por handler.py

Nombre centralizado de la función.

El local evita repetir la misma interpolación en Lambda, IAM y CloudWatch.
*/
locals {
  function_name = "${var.project_name}-${var.environment}-dynamodb-audit"
}

/*
Grupo de logs creado explícitamente.

Si no lo declaráramos, Lambda intentaría crearlo automáticamente y el rol
necesitaría logs:CreateLogGroup sobre recursos más amplios.

Al crearlo con Terraform controlamos nombre, tags y retención.
*/
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.function_name}-logs"
  }
}

/*
Función Lambda de auditoría.

El hash del ZIP permite que Terraform detecte cambios reales en el código.
La arquitectura ARM64 reduce costo para este código Python, que no utiliza
dependencias binarias.

No se configura vpc_config: la función consume DynamoDB Streams y CloudWatch
mediante APIs administradas de AWS y no necesita acceder a RDS.
*/
resource "aws_lambda_function" "this" {
  function_name = local.function_name
  description   = "Audita cambios de la tabla DynamoDB de TicketFlow."

  role    = aws_iam_role.this.arn
  runtime = var.runtime
  handler = var.handler

  filename         = var.package_file
  source_code_hash = filebase64sha256(var.package_file)

  architectures = ["arm64"]

  memory_size = var.memory_size
  timeout     = var.timeout_seconds

  /*
  Limita el máximo de ejecuciones simultáneas para controlar costos y evitar
  que una ráfaga del stream consuma toda la concurrencia de la cuenta.
  */
  reserved_concurrent_executions = 2

  environment {
    variables = {
      LOG_LEVEL   = "INFO"
      ENVIRONMENT = var.environment
    }
  }

  /*
  Activa trazabilidad distribuida mediante AWS X-Ray.
  */
  tracing_config {
    mode = "Active"
  }

  /*
  AWS envuelve los mensajes de la función en registros JSON estructurados.
  */
  logging_config {
    log_format            = "JSON"
    application_log_level = "INFO"
    system_log_level      = "WARN"
  }

  /*
  Garantiza que el grupo de logs y la política estén disponibles antes de que
  Lambda pueda ejecutar la función.
  */
  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.execution,
  ]

  tags = {
    Name = local.function_name
  }
}