/*
Cola de fallos de DynamoDB Streams.

Si un registro continúa fallando después de los reintentos configurados, Lambda
envía a esta cola la información necesaria para investigarlo y reprocesarlo.

No se mezcla con la DLQ de generación de entradas porque cada flujo debe tener
su propio ciclo de errores, alarmas y permisos.

Esta cola conserva los fallos durante 14 días y cifra los mensajes en reposo

*/
resource "aws_sqs_queue" "stream_failures" {
  name = "${local.function_name}-failures"

  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = {
    Name    = "${local.function_name}-failures"
    Purpose = "failed-dynamodb-stream-events"
  }
}