/*
Repositorios privados de imágenes.

for_each crea un repositorio por cada nombre lógico recibido. Con los valores
actuales se crearán:

- ticketflow-dev-api
- ticketflow-dev-worker
*/
resource "aws_ecr_repository" "this" {
  for_each = var.repository_names

  name                 = "${var.project_name}-${var.environment}-${each.value}"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  /*
  Ejecuta el escaneo básico de vulnerabilidades cuando se sube una imagen.
  El CI/CD también realizará un escaneo local con Trivy antes del push.
  */
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  /*
  Cifra las capas almacenadas utilizando cifrado administrado por AWS.
  Más adelante podríamos sustituirlo por una clave KMS propia.
  */
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-${each.value}"
    Component = each.value
  }
}

/*
Política de ciclo de vida.

Regla 1:
Elimina imágenes sin etiqueta después del período configurado. Estas imágenes
suelen quedar como capas intermedias o tags eliminados.

Regla 2:
Conserva solamente las imágenes etiquetadas más recientes hasta el máximo
configurado.
*/
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Eliminar imágenes sin etiqueta antiguas"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_expiration_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Conservar solamente las imágenes más recientes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}