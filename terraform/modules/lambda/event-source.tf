/*
Event Source Mapping entre DynamoDB Streams y Lambda.

AWS mantiene lectores sobre los shards del stream y entrega registros en lotes
a la función. No necesitamos crear un cron ni invocar Lambda manualmente.

Significado de starting_position = "LATEST":
- La Lambda empieza con eventos generados después de habilitar la asociación.
- No intenta reprocesar cambios históricos.
- Los cambios futuros se entregan automáticamente.
Flujo de error:
Lote falla
  → reintento
  → bisect del lote
  → máximo 3 reintentos / 1 hora
  → SQS stream_failures

*/
resource "aws_lambda_event_source_mapping" "dynamodb_stream" {
  event_source_arn = var.dynamodb_stream_arn
  function_name    = aws_lambda_function.this.arn

  enabled           = true
  starting_position = "LATEST"

  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.maximum_batching_window_seconds

  /*
  Si un lote falla, AWS lo divide para aislar el registro problemático.
  Esto evita que un único evento incorrecto impida procesar todo el lote.
  */
  bisect_batch_on_function_error = true

  /*
  Un registro puede reintentarse tres veces y durante un máximo de una hora.
  Si continúa fallando se envía a la cola stream_failures.
  */
  maximum_retry_attempts        = 3
  maximum_record_age_in_seconds = 3600

  /*
  Mantiene un único procesador por shard para conservar el orden de los
  cambios relacionados.
  */
  parallelization_factor = 1

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.stream_failures.arn
    }
  }
}