/*
Tabla DynamoDB principal de TicketFlow.

DynamoDB no utiliza columnas rígidas como una base relacional. Solo declaramos
los atributos que participan en claves e índices.

Ejemplos futuros:

PK = "REQUEST#<request-id>"
SK = "IDEMPOTENCY"
    → evita procesar dos veces una solicitud.

PK = "RESERVATION#<reservation-id>"
SK = "STATUS"
    → almacena el estado rápido de una reserva.

GSI1PK y GSI1SK permiten consultar los mismos elementos desde otra perspectiva
sin recorrer toda la tabla.

Este módulo creará una sola tabla, pero con capacidad para distintos patrones de acceso. DynamoDB no ejecuta las líneas secuencialmente: Terraform construye el recurso usando todos los argumentos del bloque y después llama a AWS.

*/
resource "aws_dynamodb_table" "this" {
  name         = "${var.project_name}-${var.environment}-application"
  billing_mode = "PAY_PER_REQUEST"
  /*
  DynamoDB Streams publica un evento cada vez que se inserta, modifica o elimina
  un elemento.

  KEYS_ONLY incluye únicamente PK y SK. La Lambda de auditoría no necesita el
  contenido completo, lo que reduce la exposición de información sensible.
  */
  stream_enabled   = true
  stream_view_type = "KEYS_ONLY"


  /*
  La clave primaria se declara como una lista de objetos.

  HASH es la clave de partición y RANGE es la clave de ordenamiento.
  */
  /*
  Clave primaria de la tabla.

  PK es la clave de partición y SK es la clave de ordenamiento.
  */
  hash_key  = "PK"
  range_key = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  /*
  Índice secundario global.

  Permite realizar consultas utilizando GSI1PK y GSI1SK sin depender de la
  clave primaria PK/SK. projection_type = "ALL" copia todos los atributos de
  cada elemento al índice, facilitando las consultas del laboratorio.
  */
  /*
Índice secundario global.

En AWS Provider 6.61, key_schema se utiliza dentro del índice para declarar
sus claves. GSI1PK permite distribuir los elementos y GSI1SK ordenarlos.
*/
  global_secondary_index {
    name            = "GSI1"
    projection_type = "ALL"

    key_schema {
      attribute_name = "GSI1PK"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "GSI1SK"
      key_type       = "RANGE"
    }
  }

  /*
  DynamoDB eliminará automáticamente los elementos cuyo atributo expires_at
  contenga una marca de tiempo Unix vencida.

  Esto será útil para claves de idempotencia y datos temporales.
  */
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  /*
  Permite recuperar la tabla a un instante anterior dentro del período
  soportado por DynamoDB.
  */
  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  /*
  Habilita cifrado en reposo. Al no indicar kms_key_arn, DynamoDB utiliza
  una clave administrada por AWS.
  */
  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = var.deletion_protection_enabled

  tags = {
    Name = "${var.project_name}-${var.environment}-application"
  }
}