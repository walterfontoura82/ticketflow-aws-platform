/*
Política de confianza.

Permite que únicamente el servicio AWS Lambda asuma este rol. No concede
permisos sobre otros recursos.
*/
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowLambdaService"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

/*
Rol que AWS Lambda asumirá durante cada ejecución.
*/
resource "aws_iam_role" "this" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${local.function_name}-role"
  }
}

/*
Política de mínimo privilegio de la Lambda.

Cada statement representa una responsabilidad independiente.
*/
data "aws_iam_policy_document" "execution" {
  /*
  Permite escribir solamente en el grupo de logs creado para esta función.
  */
  statement {
    sid    = "WriteFunctionLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "${aws_cloudwatch_log_group.this.arn}:*",
    ]
  }

  /*
  Permite leer registros del stream concreto de DynamoDB.
  */
  statement {
    sid    = "ReadDynamoDBStream"
    effect = "Allow"

    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
    ]

    resources = [
      var.dynamodb_stream_arn,
    ]
  }

  /*
  ListStreams no admite una restricción útil a un ARN individual.
  La acción permitida sigue siendo únicamente de lectura.
  */
  statement {
    sid       = "ListDynamoDBStreams"
    effect    = "Allow"
    actions   = ["dynamodb:ListStreams"]
    resources = ["*"]
  }

  /*
  Permite publicar telemetría en AWS X-Ray.
  */
  statement {
    sid    = "WriteXRayTelemetry"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]

    resources = ["*"]
  }

  /*
  Permite enviar únicamente a la cola de fallos propia de esta Lambda.
  */
  statement {
    sid    = "SendFailedEventsToQueue"
    effect = "Allow"

    actions = [
      "sqs:SendMessage",
    ]

    resources = [
      aws_sqs_queue.stream_failures.arn,
    ]
  }
}

/*
Política inline asociada al rol.

Una política inline queda ligada al ciclo de vida de este rol y evita crear
una política IAM reutilizable innecesaria.
*/
resource "aws_iam_role_policy" "execution" {
  name   = "${local.function_name}-execution"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.execution.json
}
