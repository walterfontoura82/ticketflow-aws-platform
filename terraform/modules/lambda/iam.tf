/*
Política de confianza.

Permite que únicamente el servicio AWS Lambda asuma este rol. No concede
permisos sobre recursos; solamente establece quién puede utilizar la identidad.
Por qué usamos una política propia:
- Evitamos conceder permisos amplios mediante políticas administradas genéricas.
- La Lambda no puede escribir ni borrar elementos de DynamoDB.
- Solo puede leer el stream.
- No tiene acceso a RDS, SQS, S3 ni Secrets Manager.
- X-Ray y ListStreams requieren Resource = "*", pero con acciones muy limitadas.
local.function_name se declarará en main.tf; Terraform analiza todos los archivos del módulo juntos, sin importar el orden en que los creemos.

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

  /*
    Permite enviar únicamente a la cola de fallos propia de esta Lambda.

    Este permiso es necesario para destination_config del Event Source Mapping.
    No concede acceso a otras colas SQS.
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

resource "aws_iam_role" "this" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${local.function_name}-role"
  }
}

/*
Política de mínimo privilegio de la Lambda.

Separamos los permisos por responsabilidad:

- CloudWatch Logs: escribir logs en el grupo concreto de esta función.
- DynamoDB Streams: leer solamente el stream configurado.
- ListStreams: AWS no permite restringir esta acción a un ARN específico.
- X-Ray: publicar segmentos de trazabilidad.
*/
data "aws_iam_policy_document" "execution" {
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

  statement {
    sid       = "ListDynamoDBStreams"
    effect    = "Allow"
    actions   = ["dynamodb:ListStreams"]
    resources = ["*"]
  }

  statement {
    sid    = "WriteXRayTelemetry"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "${local.function_name}-execution"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.execution.json
}