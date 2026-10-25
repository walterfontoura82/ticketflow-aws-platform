# GitHub Actions OIDC para TicketFlow

## 1. Objetivo

Esta configuración permite que GitHub Actions se autentique en AWS sin guardar
un `AWS_ACCESS_KEY_ID` y un `AWS_SECRET_ACCESS_KEY` permanentes en GitHub.

GitHub demuestra ante AWS qué repositorio, rama o ambiente está ejecutando el
workflow. Si AWS valida esa identidad, entrega credenciales temporales para el
rol `ticketflow-dev-github-actions-cd`.

El rol puede desplegar las aplicaciones de TicketFlow, pero no recibe acceso
administrativo general sobre toda la cuenta.

## 2. Qué significa OIDC

OIDC significa **OpenID Connect**. Es un protocolo de identidad construido
sobre OAuth 2.0.

En este proyecto intervienen tres componentes:

1. **GitHub Actions**, que emite un token OIDC firmado para un workflow.
2. **AWS IAM**, que confía en el emisor OIDC oficial de GitHub.
3. **AWS STS**, que intercambia el token por credenciales AWS temporales.

El token OIDC contiene *claims*, es decir, datos verificables sobre la ejecución:

- `iss`: quién emitió el token (`https://token.actions.githubusercontent.com`).
- `aud`: para quién fue emitido (`sts.amazonaws.com`).
- `sub`: qué repositorio, rama o ambiente originó la ejecución.
- Datos adicionales del workflow, commit y repositorio.

OIDC no crea un usuario IAM y no entrega una contraseña o access key fija.

## 3. Flujo completo de autenticación

```text
Push a main
    │
    ▼
GitHub Actions inicia el workflow de CD
    │
    ├─ Solicita a GitHub un token OIDC de corta duración
    │
    ▼
AWS STS: AssumeRoleWithWebIdentity
    │
    ├─ Comprueba la firma del token
    ├─ Comprueba que aud = sts.amazonaws.com
    ├─ Comprueba repositorio, rama o environment en sub
    │
    ▼
Credenciales AWS temporales
    │
    ├─ Access key temporal
    ├─ Secret key temporal
    └─ Session token temporal
    │
    ▼
El workflow despliega únicamente los recursos autorizados
```

Las credenciales expiran al finalizar su sesión. No quedan almacenadas como
secrets permanentes en GitHub.

## 4. Código agregado

Se creó el módulo:

```text
terraform/modules/github-oidc/
├── main.tf
├── outputs.tf
└── variables.tf
```

También se modificaron:

```text
terraform/environments/dev/main.tf
terraform/environments/dev/outputs.tf
```

### `variables.tf`

Define todo lo que necesita el módulo para aplicar permisos sobre recursos
concretos:

- Repositorio GitHub autorizado.
- ARN de los repositorios ECR.
- Clúster y servicio ECS.
- Roles de ejecución y tarea de ECS.
- Clúster EKS.
- Bucket S3 y distribución CloudFront.
- Función Lambda de auditoría.

Los valores se reciben desde otros módulos Terraform. De esa manera no se
repiten IDs de cuenta, nombres o ARN escritos manualmente.

### Datos de cuenta, región y partición

El módulo consulta dinámicamente:

```hcl
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
```

Esto permite reconstruir el laboratorio en un sandbox nuevo sin fijar el ID de
la cuenta anterior. También evita asumir siempre la partición comercial `aws`.

### Proveedor OIDC de GitHub

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
```

Este recurso registra a GitHub como proveedor de identidad confiable en la
cuenta AWS actual.

- `url` identifica al emisor oficial de tokens de GitHub Actions.
- `client_id_list` limita el token a AWS STS.
- `thumbprint_list` permite a IAM validar la cadena TLS del proveedor.

Debe existir una sola instancia equivalente por cuenta AWS. En cada sandbox
nuevo se crea nuevamente porque la cuenta también es nueva.

### Política de confianza del rol

La política de confianza permite únicamente:

```hcl
actions = ["sts:AssumeRoleWithWebIdentity"]
```

El principal federado es el proveedor OIDC recién creado. Además, se validan
dos condiciones importantes:

```hcl
aud = "sts.amazonaws.com"
```

y alguno de estos sujetos:

```text
repo:walterfontoura82/ticketflow-aws-platform:ref:refs/heads/main
repo:walterfontoura82/ticketflow-aws-platform:environment:dev
```

Por lo tanto, otro repositorio o una rama diferente no puede asumir el rol.
La segunda forma permite usar posteriormente un GitHub Environment llamado
`dev`, con sus aprobaciones y reglas de protección.

### Rol de GitHub Actions

Se crea:

```text
ticketflow-dev-github-actions-cd
```

Su sesión máxima es de una hora. El rol no tiene access keys propias: solo se
puede obtener una sesión temporal presentando un token OIDC válido.

## 5. Permisos de despliegue

La política inline está dividida en bloques con responsabilidades concretas.

### ECR

Permite obtener un token de login y publicar capas e imágenes exclusivamente
en los repositorios `ticketflow-dev-api` y `ticketflow-dev-worker`.

El permiso `ecr:GetAuthorizationToken` requiere `Resource = "*"` por diseño de
AWS. Las operaciones que modifican imágenes sí están limitadas a los ARN de los
dos repositorios.

### ECS Fargate

Permite:

- Consultar la task definition actual.
- Registrar una nueva revisión de la task definition.
- Consultar y actualizar el servicio del worker.

`iam:PassRole` está limitado a los roles de ejecución y aplicación del worker,
y contiene esta condición:

```text
iam:PassedToService = ecs-tasks.amazonaws.com
```

Esto evita que GitHub pase esos roles a otro servicio AWS.

### EKS y Kubernetes

IAM permite `eks:DescribeCluster` solamente sobre `ticketflow-dev`. Este permiso
se usa al ejecutar `aws eks update-kubeconfig`.

Además se crean:

```text
aws_eks_access_entry
aws_eks_access_policy_association
```

La entrada conecta el rol IAM de GitHub con el clúster. La asociación aplica
`AmazonEKSClusterAdminPolicy` únicamente dentro de ese clúster.

Esto es necesario porque existen dos controles diferentes:

1. **Autenticación AWS/IAM:** quién es GitHub.
2. **Autorización Kubernetes:** qué puede hacer esa identidad dentro de EKS.

Sin la entrada de acceso, el rol podría consultar EKS desde AWS pero `kubectl`
respondería con un error de autorización.

El acceso de administrador es amplio dentro del clúster y permite aplicar el
namespace, Deployment, Service, Job, Ingress y demás manifiestos. No concede
administración sobre otros clústeres ni sobre toda la cuenta AWS. En una etapa
posterior puede reemplazarse por RBAC más granular.

### Frontend: S3 y CloudFront

El rol puede:

- Listar el bucket privado del frontend.
- Crear, leer y borrar objetos del bucket.
- Crear y consultar invalidaciones de la distribución CloudFront.

Esto permite ejecutar:

```bash
aws s3 sync services/frontend/dist/ s3://BUCKET --delete
aws cloudfront create-invalidation --distribution-id ID --paths '/*'
```

No puede escribir en otros buckets ni invalidar otras distribuciones.

### Lambda

El rol puede consultar la configuración y actualizar el código únicamente de
la función Lambda de auditoría. No puede modificar sus permisos IAM ni otras
funciones.

## 6. Integración en el ambiente `dev`

En `terraform/environments/dev/main.tf`, el módulo recibe directamente outputs
de la infraestructura existente:

```text
module.ecr            ─┐
module.ecs_workers     ├─► module.github_oidc
module.eks             │
module.frontend        │
module.lambda_audit   ─┘
```

Estas referencias también crean dependencias Terraform. Por ejemplo, el acceso
EKS no se intenta crear antes de que exista el clúster.

Se agregaron dos outputs al entorno:

```text
github_actions_oidc_provider_arn
github_actions_cd_role_arn
```

El segundo será el ARN que utilizará el workflow de GitHub Actions.

## 7. Recursos que crea el plan

El plan esperado contiene cinco recursos:

1. `aws_iam_openid_connect_provider.github`
2. `aws_iam_role.github_actions`
3. `aws_iam_role_policy.deployment`
4. `aws_eks_access_entry.github_actions`
5. `aws_eks_access_policy_association.github_actions`

No debe reemplazar ni destruir la infraestructura existente.

## 8. Verificación después del apply

```bash
terraform -chdir=terraform/environments/dev output \
  -raw github_actions_cd_role_arn
```

```bash
aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[].Arn' \
  --output table
```

```bash
aws eks list-access-entries \
  --cluster-name ticketflow-dev \
  --output table
```

Para revisar quién puede asumir el rol:

```bash
aws iam get-role \
  --role-name ticketflow-dev-github-actions-cd \
  --query 'Role.AssumeRolePolicyDocument'
```

## 9. Uso posterior desde GitHub Actions

El workflow de CD necesitará permiso para solicitar el token OIDC:

```yaml
permissions:
  contents: read
  id-token: write
```

Luego configurará credenciales temporales:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v5
  with:
    role-to-assume: arn:aws:iam::CUENTA:role/ticketflow-dev-github-actions-cd
    aws-region: us-east-1
```

La action solicita el token a GitHub, llama a STS y exporta las credenciales
temporales solamente durante el job. No hace falta crear secrets con access
keys.

El futuro workflow podrá seguir este orden:

1. Esperar que CI termine correctamente.
2. Asumir el rol mediante OIDC.
3. Construir imágenes con tags inmutables basados en el commit.
4. Escanearlas y publicarlas en ECR.
5. Actualizar el worker ECS.
6. Actualizar la API en EKS.
7. Construir y sincronizar el frontend con S3.
8. Invalidar CloudFront.
9. Ejecutar verificaciones de salud posteriores al despliegue.

Como el endpoint público de EKS está limitado a la IP del administrador, el
runner hospedado por GitHub no puede acceder inicialmente. El workflow consulta
su IP pública, la agrega temporalmente como `/32`, despliega y restaura la lista
original en un paso `always()`. Es una solución práctica para el laboratorio.
En producción se recomienda un runner privado dentro de la VPC para mantener el
endpoint exclusivamente privado y eliminar esta apertura temporal.

## 10. Qué OIDC no automatiza

OIDC resuelve la autenticación segura entre GitHub y AWS. Por sí solo no:

- Construye imágenes.
- Ejecuta Terraform.
- Actualiza ECS o EKS.
- Publica el frontend.
- Decide qué commit desplegar.

Esas tareas se definirán en `.github/workflows/cd.yml`. OIDC es la identidad
segura que permite ejecutarlas.

## 11. Relación con el reinicio del sandbox

Al vencer el sandbox cambia la cuenta AWS y desaparece toda su infraestructura,
incluido el proveedor OIDC y el rol. El proceso general será:

1. Confirmar cuenta y región.
2. Migrar el backend al sandbox actual.
3. Crear el bucket de state.
4. Crear ECR y publicar las imágenes requeridas para el arranque.
5. Aplicar la infraestructura completa, incluido OIDC.
6. A partir de ahí, GitHub Actions podrá asumir el nuevo rol.

El ARN del rol cambia porque contiene el nuevo ID de cuenta. Para evitar editar
el workflow en cada reinicio, posteriormente conviene almacenar el ARN como
variable de GitHub Environment o automatizar su actualización durante el
bootstrap.

## 12. Consideraciones de seguridad

- No guardar access keys AWS permanentes en GitHub.
- Mantener `id-token: write` solamente en jobs que necesitan AWS.
- No ejecutar CD desde pull requests de forks.
- Mantener la confianza limitada al repositorio y a `main` o `dev`.
- Usar tags de imágenes inmutables, nunca depender únicamente de `latest`.
- Conservar CI como requisito previo al despliegue.
- Proteger el GitHub Environment `dev` si se desean aprobaciones manuales.
- Revisar periódicamente los permisos y reducirlos cuando el flujo definitivo
  permita reemplazar la administración del clúster por RBAC granular.
- Auditar sesiones mediante AWS CloudTrail; las llamadas quedan atribuidas al
  rol `ticketflow-dev-github-actions-cd`.

## 13. Diagnóstico de errores frecuentes

### `No OpenIDConnect provider found`

El proveedor no existe en la cuenta actual o Terraform todavía no fue aplicado.

### `Not authorized to perform sts:AssumeRoleWithWebIdentity`

Revisar el repositorio, la rama, el GitHub Environment, `aud` y el ARN del rol.
El valor `sub` debe coincidir con alguna condición de la política de confianza.

### `Credentials could not be loaded`

Confirmar que el workflow tenga `permissions: id-token: write` y que el job haya
ejecutado `configure-aws-credentials`.

### `kubectl: Unauthorized`

La autenticación OIDC pudo funcionar, pero falta o es incorrecta la entrada de
acceso de EKS o su asociación de política.

### `AccessDenied` al publicar una imagen o el frontend

Comprobar que el workflow esté usando los repositorios, bucket y distribución
del sandbox actual. Los permisos están intencionalmente limitados a esos ARN.

### El proveedor OIDC ya existe

AWS permite un proveedor equivalente por cuenta. Si fue creado fuera de este
state, debe importarse en lugar de intentar crear otro:

```bash
terraform -chdir=terraform/environments/dev import \
  module.github_oidc.aws_iam_openid_connect_provider.github \
  arn:aws:iam::CUENTA:oidc-provider/token.actions.githubusercontent.com
```

## 14. Resumen

La configuración implementa una relación de confianza sin secretos permanentes:

```text
GitHub Actions
    └─ token OIDC firmado
        └─ AWS STS valida identidad
            └─ rol temporal y limitado
                ├─ ECR
                ├─ ECS
                ├─ EKS
                ├─ S3/CloudFront
                └─ Lambda
```

El resultado es una base segura para implementar CD: CI valida el cambio y CD
podrá desplegarlo usando credenciales temporales, trazables y de alcance
reducido.
