# Política de confianza compartida por los roles de ECS.
# Solo el servicio ecs-tasks.amazonaws.com puede asumirlos.
data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Rol usado por Fargate antes de iniciar el contenedor:
# descarga la imagen desde ECR y publica logs en CloudWatch.
resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-${var.environment}-worker-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Rol utilizado por el código Python dentro del contenedor.
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-${var.environment}-worker-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

# Permisos mínimos para consumir y confirmar mensajes de la cola.
data "aws_iam_policy_document" "task" {
  statement {
    sid    = "ConsumeTicketQueue"
    effect = "Allow"

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage"
    ]

    resources = [var.queue_arn]
  }

  # Permisos necesarios para consultar y actualizar el estado
  # de la reserva procesada por el worker.
  statement {
    sid    = "UpdateTicketState"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]

    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "${var.project_name}-${var.environment}-worker-policy"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}