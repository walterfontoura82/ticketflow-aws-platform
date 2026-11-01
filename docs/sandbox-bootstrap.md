# Reconstrucción del sandbox de TicketFlow

## Objetivo

El procedimiento reduce la reconstrucción de una cuenta sandbox nueva a dos
acciones:

```bash
./scripts/bootstrap-sandbox.sh
git push
```

El primer comando prepara la cuenta e infraestructura. El `push` ejecuta CI y,
si todos los controles terminan correctamente, CD publica las versiones del
commit mediante credenciales temporales OIDC.

## Qué queda automatizado

`bootstrap-sandbox.sh` realiza estas etapas:

1. Verifica herramientas, identidad AWS, región e IP pública.
2. Invoca `switch-sandbox-account.sh` cuando cambia la cuenta.
3. Crea y migra el backend S3 de Terraform.
4. Actualiza el CIDR local autorizado para EKS.
5. Ejecuta tests y empaqueta la Lambda de auditoría.
6. Inicializa y valida Terraform.
7. Crea ECR mediante un plan dirigido.
8. Construye, escanea y publica las imágenes iniciales de API y worker.
9. Crea la infraestructura principal mediante un plan sin destrucciones.
10. Configura `kubectl`, instala AWS Load Balancer Controller con Helm y
    despliega los manifiestos Kustomize.
11. Espera la migración, el rollout y el health check del ALB.
12. Crea frontend, CloudFront y la identidad OIDC de GitHub.
13. Actualiza `AWS_ROLE_ARN` en el GitHub Environment `dev`.
14. Exige que el plan final de Terraform quede sin cambios.

## Requisitos locales

- Sesión AWS CLI válida en la cuenta nueva.
- Región AWS CLI `us-east-1`.
- Docker activo.
- Terraform, AWS CLI, GitHub CLI, kubectl, Helm, jq, curl, sed, grep y Trivy.
- Autenticación previa de GitHub CLI (`gh auth status`).
- Acceso al repositorio `walterfontoura82/ticketflow-aws-platform`.

Comprobación inicial recomendada:

```bash
aws sts get-caller-identity
aws configure get region
gh auth status
docker info >/dev/null
git status --short
```

## Ejecución

Desde la raíz del repositorio:

```bash
./scripts/bootstrap-sandbox.sh
```

El script solicita confirmaciones explícitas:

- `CREATE`: creación del backend S3 cuando cambia la cuenta.
- `APPLY`: infraestructura principal.
- `APPLY`: frontend y OIDC.

Las palabras deben escribirse exactamente como aparecen. Cancelar antes del
apply del backend restaura `backend.tf` y las referencias de la cuenta previa.

## Controles de seguridad

- Verifica que la identidad AWS coincida con la cuenta detectada.
- Rechaza una región diferente de `us-east-1`.
- Guarda artefactos anteriores bajo `.sandbox-recovery/`.
- Rechaza planes principales que contengan una acción `delete`.
- Nunca ejecuta un plan principal sin confirmación humana.
- Escanea ambas imágenes con Trivy antes de publicarlas.
- Guarda el login ECR en un directorio Docker temporal y lo elimina al salir;
  no persiste credenciales en `~/.docker/config.json`.
- Usa un kubeconfig temporal durante el bootstrap y no sobrescribe el contexto
  personal de `~/.kube/config`.
- Aísla también la configuración, caché y datos temporales de Helm; no modifica
  el contenido de `~/.config/helm`, `~/.cache/helm` ni `~/.local/share/helm`.
- El plan de finalización solo puede contener cambios de outputs; cualquier
  cambio real de infraestructura detiene el script.
- No ejecuta `git add`, `git commit` ni `git push`.
- Una reejecución conserva la imagen de API que CD ya dejó activa.

## Revisión y push

Cuando el bootstrap termina:

```bash
terraform -chdir=terraform/environments/dev plan
git status --short
git diff --check
gitleaks dir . --redact --no-banner
```

El plan debe indicar `No changes`. Luego se revisan y versionan únicamente los
archivos intencionales de cuenta y acceso. `reinicioSandbox.md` está excluido
localmente mediante `.git/info/exclude` y nunca debe incluirse en el commit.

Para conservar el acceso interactivo después del bootstrap:

```bash
aws eks update-kubeconfig --region us-east-1 --name ticketflow-dev
```

Finalmente:

```bash
git push
```

El push ejecuta:

```text
CI → OIDC → CD → ECR/Lambda/ECS/EKS/S3/CloudFront
```

## Reanudación después de un fallo

El script está diseñado para ser reejecutable:

- Omite la creación de ECR si ya está registrado en el state.
- Omite imágenes iniciales que ya existen en ECR.
- Los recursos Terraform convergen mediante planes guardados.
- Los planes sin cambios no solicitan confirmación ni ejecutan un apply vacío.
- Helm utiliza `upgrade --install`.
- Kubernetes utiliza `apply`.
- La migración se elimina y vuelve a ejecutar de forma controlada.
- La API conserva la imagen actualmente desplegada si ya existe.

Antes de reanudar, se debe leer el último error. No deben aplicarse manualmente
planes antiguos: Terraform puede marcarlos como `stale` después de cualquier
cambio de state.

## Alcance del «único push»

Una cuenta AWS completamente nueva necesita un bootstrap inicial porque el rol
OIDC todavía no existe. Después de ejecutar el script, todos los cambios de
aplicación se despliegan con un solo `git push`.

Esto evita access keys permanentes en GitHub: el CD asume el rol
`ticketflow-dev-github-actions-cd` usando un token OIDC temporal.
