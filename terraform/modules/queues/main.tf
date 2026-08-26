/*
Dead Letter Queue (DLQ).

Recibe los mensajes que no pudieron procesarse después de varios intentos.
Tiene una retención mayor que la cola principal para dar tiempo a investigar,
corregir el problema y eventualmente reprocesarlos.
*/
resource "aws_sqs_queue" "dead_letter" {
  name = "${var.project_name}-${var.environment}-ticket-generation-dlq"

  message_retention_seconds = var.dlq_message_retention_seconds
  sqs_managed_sse_enabled   = true

  tags = {
    Name    = "${var.project_name}-${var.environment}-ticket-generation-dlq"
    Purpose = "failed-ticket-generation-jobs"
  }
}

/*
Cola principal de trabajos.

La API publicará un mensaje cuando deba generarse una entrada. Los workers de
ECS/Fargate consumirán los mensajes y ejecutarán el procesamiento asíncrono.

visibility_timeout_seconds evita que dos workers procesen simultáneamente el
mismo mensaje durante el intervalo configurado.

receive_wait_time_seconds habilita long polling para reducir respuestas vacías.
*/
resource "aws_sqs_queue" "ticket_generation" {
  name = "${var.project_name}-${var.environment}-ticket-generation"

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  sqs_managed_sse_enabled = true

  /*
  Conecta la cola principal con la DLQ.

  deadLetterTargetArn indica el destino de los mensajes fallidos.
  maxReceiveCount determina cuántas recepciones se permiten antes de moverlos.
  */
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name    = "${var.project_name}-${var.environment}-ticket-generation"
    Purpose = "asynchronous-ticket-generation"
  }
}

/*
Restringe qué cola puede enviar mensajes a la DLQ.

Aunque la DLQ exista, solo la cola ticket_generation queda autorizada como
origen de redrive. Esto evita que otras colas de la cuenta la utilicen
accidentalmente.

Terraform deducirá las dependencias:
DLQ
  → cola principal usa el ARN de la DLQ
  → política utiliza la URL de la DLQ y el ARN de la cola principal
SQS cifrará los mensajes en reposo usando cifrado administrado por el servicio. Los permisos IAM para productores y consumidores los agregaremos cuando creemos Lambda, EKS y ECS.

*/
resource "aws_sqs_queue_redrive_allow_policy" "dead_letter" {
  queue_url = aws_sqs_queue.dead_letter.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns = [
      aws_sqs_queue.ticket_generation.arn
    ]
  })
}