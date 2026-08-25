# Cómo fluye Terraform en TicketFlow

Esta guía explica cómo Terraform interpreta el proyecto, cómo viajan los valores entre archivos y módulos, y cómo decide el orden de creación.

## Terraform no ejecuta archivos línea por línea

Terraform es declarativo: el código describe el estado final deseado. No ejecuta necesariamente:

```text
backend.tf → variables.tf → main.tf → route.tf → outputs.tf
```

Tampoco considera que `main.tf` sea el primer archivo. Los nombres son convenciones para facilitar la lectura humana.

Cuando ejecutamos Terraform dentro de una carpeta:

1. Lee conjuntamente todos los archivos `*.tf` de esa carpeta.
2. Los combina como una sola configuración o **root module**.
3. Resuelve variables, expresiones, módulos y referencias.
4. Consulta el state y la infraestructura real.
5. Construye un grafo de dependencias.
6. Calcula el plan.
7. En `apply`, ejecuta en paralelo lo que no tenga dependencias pendientes.

## Estructura actual

```text
terraform/
├── environments/dev/          Root module de desarrollo
│   ├── backend.tf
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── main.tf
│
└── modules/networking/         Módulo hijo reutilizable
    ├── variables.tf
    ├── main.tf
    ├── nat.tf
    ├── route.tf
    └── outputs.tf
```

El punto de entrada operativo es la carpeta `terraform/environments/dev`, no un archivo individual:

```bash
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/dev plan
```

## 1. Backend: dónde vive el state

Archivo: `terraform/environments/dev/backend.tf`.

```hcl
terraform {
  backend "s3" {
    bucket       = "ticketflow-tfstate-730335523130-us-east-1"
    key          = "environments/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Esto ubica el state en:

```text
S3 bucket
└── environments/dev/terraform.tfstate
```

El state relaciona las direcciones de Terraform con los recursos reales de AWS. `use_lockfile` impide dos modificaciones simultáneas.

El backend obtiene credenciales del entorno: AWS CLI localmente y OIDC en GitHub Actions. No usa contraseñas escritas en HCL.

## 2. Versiones y providers

Archivo: `terraform/environments/dev/versions.tf`.

```hcl
required_version = ">= 1.15.0, < 2.0.0"
```

Terraform verifica que la herramienta instalada cumpla ese rango. Después resuelve el provider:

```text
hashicorp/aws ~> 6.0
        │
        ▼
versión exacta seleccionada
        │
        ▼
.terraform.lock.hcl
```

El lock file registra la versión exacta y sus checksums; por eso se versiona en Git.

## 3. Variables del ambiente

Archivo: `terraform/environments/dev/variables.tf`.

Ejemplo:

```hcl
variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}
```

Cada referencia `var.vpc_cidr` obtiene ese valor salvo que sea sobrescrito por una fuente de mayor precedencia.

Valores actuales:

```text
var.aws_region               = us-east-1
var.project_name             = ticketflow
var.environment              = dev
var.vpc_cidr                 = 10.10.0.0/16
var.availability_zones       = [us-east-1a, us-east-1b]
var.public_subnet_cidrs      = [10.10.0.0/24, 10.10.1.0/24]
var.private_app_subnet_cidrs = [10.10.10.0/24, 10.10.11.0/24]
var.private_db_subnet_cidrs  = [10.10.20.0/24, 10.10.21.0/24]
var.enable_nat_gateway       = true
var.single_nat_gateway       = true
```

Una variable del root module y una variable del módulo hijo son objetos diferentes, aunque tengan el mismo nombre. El valor debe pasarse explícitamente.

## 4. Provider AWS

Archivo: `terraform/environments/dev/providers.tf`.

```text
variables.tf
└── var.aws_region = us-east-1
        │
        ▼
providers.tf
└── provider "aws" { region = var.aws_region }
        │
        ▼
Recursos administrados en us-east-1
```

`default_tags` agrega etiquetas comunes a los recursos compatibles. Las credenciales no se escriben en el provider.

## 5. El root module invoca networking

Archivo: `terraform/environments/dev/main.tf`.

```hcl
module "networking" {
  source = "../../modules/networking"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  enable_nat_gateway       = var.enable_nat_gateway
  single_nat_gateway       = var.single_nat_gateway
}
```

`source` resuelve:

```text
terraform/environments/dev
└── ../../modules/networking
              │
              ▼
terraform/modules/networking
```

### Viaje completo de `vpc_cidr`

```text
environments/dev/variables.tf
│ variable "vpc_cidr" { default = "10.10.0.0/16" }
▼
environments/dev/main.tf
│ vpc_cidr = var.vpc_cidr
▼
modules/networking/variables.tf
│ variable "vpc_cidr" { type = string }
▼
modules/networking/main.tf
│ resource "aws_vpc" "this" {
│   cidr_block = var.vpc_cidr
│ }
▼
AWS VPC: 10.10.0.0/16
```

### Viaje de `single_nat_gateway`

```text
dev/variables.tf: true
        │
        ▼
dev/main.tf: pasa el valor
        │
        ▼
networking/variables.tf: recibe booleano
        │
        ▼
networking/nat.tf: elige availability_zones[0]
        │
        ▼
Un NAT Gateway en us-east-1a
```

## 6. Variables del módulo y validaciones

Archivo: `terraform/modules/networking/variables.tf`.

```hcl
validation {
  condition     = length(var.availability_zones) == 2
  error_message = "El laboratorio requiere exactamente dos zonas."
}
```

El root entrega `["us-east-1a", "us-east-1b"]`; el módulo comprueba que haya exactamente dos elementos. Si no, `validate` o `plan` falla antes de crear recursos.

## 7. Locals: transformaciones internas

Archivo: `terraform/modules/networking/main.tf`.

Entrada:

```hcl
availability_zones  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.10.0.0/24", "10.10.1.0/24"]
```

Expresión:

```hcl
public_subnets = {
  for index, az in var.availability_zones :
  az => var.public_subnet_cidrs[index]
}
```

Resultado:

```hcl
{
  "us-east-1a" = "10.10.0.0/24"
  "us-east-1b" = "10.10.1.0/24"
}
```

Un `local` no crea recursos: calcula un valor reutilizable.

## 8. `for_each`: varias instancias

```hcl
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  availability_zone = each.key
  cidr_block        = each.value
}
```

Terraform crea:

```text
aws_subnet.public["us-east-1a"] → 10.10.0.0/24
aws_subnet.public["us-east-1b"] → 10.10.1.0/24
```

`each.key` es la zona y `each.value` es el CIDR.

## 9. Dependencias automáticas

Terraform no necesita que los recursos estén escritos en orden.

```hcl
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}
```

La referencia `aws_vpc.this.id` establece que el Internet Gateway debe esperar a la VPC.

```hcl
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
}
```

El NAT espera a la Elastic IP y a la subred pública. También declaramos `depends_on` respecto del Internet Gateway.

### Grafo simplificado

```text
aws_vpc.this
├── Internet Gateway
├── 2 subredes públicas
├── 2 subredes privadas app
├── 2 subredes privadas DB
└── tablas de rutas

Elastic IP + subred pública + Internet Gateway
└── NAT Gateway

Tabla pública + Internet Gateway
└── ruta pública 0.0.0.0/0

Tablas privadas app + NAT
└── rutas privadas 0.0.0.0/0
```

Los recursos independientes pueden crearse en paralelo.

## 10. Flujo de rutas

Archivo: `terraform/modules/networking/route.tf`.

```text
Subred pública
└── 0.0.0.0/0 → Internet Gateway

Subred privada de aplicación
└── 0.0.0.0/0 → NAT Gateway

Subred privada de base de datos
└── solamente ruta local de la VPC
```

Con `single_nat_gateway = true`, ambas tablas privadas de aplicación apuntan al NAT de `us-east-1a`. Reduce costos en `dev`, pero introduce dependencia entre zonas. Producción usará un diseño de mayor disponibilidad.

RDS no recibe una ruta predeterminada hacia Internet. La ruta `local`, creada automáticamente por AWS, permite comunicación interna dentro del CIDR de la VPC.

## 11. Outputs: valores que salen del módulo

Archivo: `terraform/modules/networking/outputs.tf`.

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}
```

Flujo:

```text
aws_vpc.this.id
        │
        ▼
output "vpc_id"
        │
        ▼
module.networking.vpc_id
```

Más adelante podremos escribir:

```hcl
module "rds" {
  source = "../../modules/rds"

  vpc_id     = module.networking.vpc_id
  subnet_ids = module.networking.private_db_subnet_ids
}
```

La referencia también hace que RDS espere a que networking haya producido las subredes.

## 12. Qué hace cada comando

### `terraform init`

```text
Configura backend S3
├── configura locking
├── descarga módulos
├── descarga providers
└── crea/actualiza .terraform.lock.hcl
```

No crea VPC, subredes ni NAT.

### `terraform fmt`

Normaliza indentación y formato. No consulta ni modifica AWS.

### `terraform validate`

Comprueba sintaxis, tipos, referencias, variables y estructura de módulos. No crea recursos.

### `terraform plan`

```text
Configuración deseada
        + state remoto
        + infraestructura AWS actual
        ↓
Plan: add / change / destroy
```

### `terraform apply`

1. Adquiere el lock remoto.
2. Actualiza la lectura de AWS.
3. Ejecuta el grafo aprobado.
4. Actualiza el state en S3.
5. Libera el lock.

## 13. Orden probable de creación

El orden proviene de dependencias, no de nombres de archivos:

```text
1. VPC

2. En paralelo, cuando sea posible:
   ├── Internet Gateway
   ├── subredes
   ├── tablas de rutas
   └── Elastic IP

3. NAT Gateway
   └── espera EIP, subred pública e IGW

4. Rutas
   ├── pública espera tabla e IGW
   └── privadas esperan tablas y NAT

5. Asociaciones
   └── esperan tabla y subred

6. Outputs
```

## 14. Direcciones dentro del state

```text
module.networking
module.networking.aws_vpc.this
module.networking.aws_subnet.public["us-east-1a"]
module.networking.aws_subnet.public["us-east-1b"]
```

Estas direcciones aparecen en `plan`, `state list` y errores.

## 15. Resumen del flujo completo

```text
environments/dev/*.tf
│
├── backend.tf ─────────────► state S3 de dev
├── versions.tf ────────────► Terraform + provider AWS
├── variables.tf ───────────► valores dev
├── providers.tf ───────────► AWS us-east-1 + tags
└── main.tf
    └── module "networking"
        │ pasa variables
        ▼
modules/networking/*.tf
│
├── variables.tf ───────────► recibe y valida
├── main.tf ────────────────► locals, VPC, IGW y subredes
├── nat.tf ─────────────────► EIP y NAT
├── route.tf ───────────────► tablas, rutas y asociaciones
└── outputs.tf ─────────────► IDs para EKS, ECS, RDS y endpoints
```

## 16. Regla mental para leer referencias

```hcl
vpc_id = aws_vpc.this.id
```

Se lee de derecha a izquierda:

1. Existe un recurso `aws_vpc` llamado internamente `this`.
2. AWS devuelve su atributo `id`.
3. El ID se asigna al argumento `vpc_id`.
4. La referencia crea una dependencia automática.

```hcl
vpc_id = module.networking.vpc_id
```

1. Existe un módulo llamado `networking`.
2. Expone un output llamado `vpc_id`.
3. El consumidor recibe el valor.
4. Terraform conecta ambos módulos en su grafo.

## 17. Preguntas para comprobar comprensión

1. ¿Por qué `main.tf` no es necesariamente el primer archivo ejecutado?
2. ¿Qué diferencia hay entre una variable del root y una del módulo hijo?
3. ¿Cómo llega `10.10.0.0/16` hasta la VPC?
4. ¿Por qué el NAT espera a la subred pública y a la EIP?
5. ¿Qué crea `for_each` al recibir dos zonas?
6. ¿Por qué RDS no tendrá ruta predeterminada a Internet?
7. ¿Cómo consumirá RDS las subredes creadas por networking?
8. ¿Qué diferencia existe entre `init`, `validate`, `plan` y `apply`?
9. ¿Qué guarda el state y por qué no se versiona en Git?
10. ¿Qué riesgo introduce un único NAT para dos AZ?

---

Este documento debe ampliarse cuando se incorporen security groups, RDS, DynamoDB, EKS, ECS, Lambda y frontend, agregando los inputs, outputs y dependencias de cada módulo.

## Cambio de cuenta sandbox

Los sandboxes temporales entregan un Account ID nuevo cuando expiran. El
script `scripts/switch-sandbox-account.sh` automatiza la reconstrucción segura
del backend:

```bash
./scripts/switch-sandbox-account.sh NUEVO_ACCOUNT_ID
```

El script valida que AWS CLI esté autenticado en esa cuenta y en `us-east-1`,
actualiza referencias al bucket, conserva artefactos locales anteriores,
genera un plan de exactamente seis recursos y exige escribir `CREATE` antes
del `apply`. Después migra el state local a S3 y reinicializa `dev`.

El script no ejecuta `git add`, no crea commits y no vuelve a desplegar la red
de `dev`. Al terminar se deben revisar los cambios y generar un plan nuevo del
ambiente antes de aplicar infraestructura.
