/*
Outputs del módulo SQS.

Los ARN se utilizarán para construir políticas IAM.
Las URL se utilizarán para publicar y consumir mensajes mediante el SDK de AWS.
Los nombres facilitan operaciones, métricas y alarmas.

Queue URL → utilizada en llamadas SendMessage, ReceiveMessage, DeleteMessage
Queue ARN → utilizado en políticas IAM y asociaciones con otros servicios

*/

output "ticket_generation_queue_name" {
  description = "Nombre de la cola principal de generación de entradas."
  value       = aws_sqs_queue.ticket_generation.name
}

output "ticket_generation_queue_url" {
  description = "URL utilizada por las aplicaciones para acceder a la cola principal."
  value       = aws_sqs_queue.ticket_generation.url
}

output "ticket_generation_queue_arn" {
  description = "ARN utilizado para autorizar acciones IAM sobre la cola principal."
  value       = aws_sqs_queue.ticket_generation.arn
}

output "dead_letter_queue_name" {
  description = "Nombre de la Dead Letter Queue."
  value       = aws_sqs_queue.dead_letter.name
}

output "dead_letter_queue_url" {
  description = "URL de la Dead Letter Queue."
  value       = aws_sqs_queue.dead_letter.url
}

output "dead_letter_queue_arn" {
  description = "ARN utilizado para permisos y alarmas sobre la Dead Letter Queue."
  value       = aws_sqs_queue.dead_letter.arn
}