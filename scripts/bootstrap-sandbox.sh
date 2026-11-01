#!/usr/bin/env bash

# Reconstruye TicketFlow en la cuenta AWS sandbox activa.
#
# Uso:
#   ./scripts/bootstrap-sandbox.sh

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly DEV_DIR="${PROJECT_ROOT}/terraform/environments/dev"
readonly REGION="us-east-1"

TEMP_DOCKER_CONFIG=""
TEMP_KUBECONFIG=""
TEMP_HELM_ROOT=""

cleanup() {
  if [[ -n "${TEMP_DOCKER_CONFIG}" &&
        -d "${TEMP_DOCKER_CONFIG}" &&
        "${TEMP_DOCKER_CONFIG}" == /tmp/ticketflow-docker.* ]]; then
    rm -rf -- "${TEMP_DOCKER_CONFIG}"
  fi

  if [[ -n "${TEMP_KUBECONFIG}" &&
        -f "${TEMP_KUBECONFIG}" &&
        "${TEMP_KUBECONFIG}" == /tmp/ticketflow-kubeconfig.* ]]; then
    rm -f -- "${TEMP_KUBECONFIG}"
  fi

  if [[ -n "${TEMP_HELM_ROOT}" &&
        -d "${TEMP_HELM_ROOT}" &&
        "${TEMP_HELM_ROOT}" == /tmp/ticketflow-helm.* ]]; then
    rm -rf -- "${TEMP_HELM_ROOT}"
  fi
}

trap cleanup EXIT

[[ $# -eq 0 ]] || {
  printf 'Uso: %s\n' "$0" >&2
  exit 1
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '\n==> %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "No se encontró el comando requerido: $1"
}

for command in \
  aws \
  terraform \
  docker \
  git \
  gh \
  kubectl \
  helm \
  jq \
  curl \
  sed \
  grep \
  trivy
do
  require_command "${command}"
done

cd -- "${PROJECT_ROOT}"

info "Validando cuenta y región"

readonly ACCOUNT_ID="$(
  aws sts get-caller-identity \
    --query Account \
    --output text
)"

readonly ACTIVE_REGION="$(aws configure get region)"

readonly PUBLIC_IP="$(
  curl -4 -fsSL https://checkip.amazonaws.com |
  tr -d '[:space:]'
)"

[[ "${ACCOUNT_ID}" =~ ^[0-9]{12}$ ]] ||
  die "AWS devolvió un Account ID inválido."

[[ "${ACTIVE_REGION}" == "${REGION}" ]] ||
  die "La región activa debe ser ${REGION}."

[[ "${PUBLIC_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  die "No se pudo determinar la IP pública."

printf 'Cuenta: %s\nRegión: %s\nIP:     %s\n' \
  "${ACCOUNT_ID}" \
  "${REGION}" \
  "${PUBLIC_IP}"

info "Comprobando referencias del backend"

readonly CONFIGURED_ACCOUNT_ID="$(
  sed -nE \
    's/.*ticketflow-tfstate-([0-9]{12})-us-east-1.*/\1/p' \
    terraform/bootstrap/main.tf |
  head -n 1
)"

[[ -n "${CONFIGURED_ACCOUNT_ID}" ]] ||
  die "No se pudo detectar la cuenta configurada en Terraform."

if [[ "${CONFIGURED_ACCOUNT_ID}" != "${ACCOUNT_ID}" ]]; then
  "${SCRIPT_DIR}/switch-sandbox-account.sh" "${ACCOUNT_ID}"
else
  info "El backend ya referencia la cuenta activa"
fi

readonly STATE_BUCKET="ticketflow-tfstate-${ACCOUNT_ID}-${REGION}"

aws s3api head-bucket \
  --bucket "${STATE_BUCKET}" >/dev/null ||
  die "El bucket de state ${STATE_BUCKET} no está disponible."

info "Actualizando acceso local a EKS"

sed -E -i \
  "s|default[[:space:]]*=[[:space:]]*\\[\"[0-9.]+/32\"\\]|default     = [\"${PUBLIC_IP}/32\"]|" \
  terraform/environments/dev/variables.tf

grep -Fq \
  "${PUBLIC_IP}/32" \
  terraform/environments/dev/variables.tf ||
  die "No se pudo actualizar el CIDR público de EKS."

info "Empaquetando Lambda"

"${SCRIPT_DIR}/package-lambda-audit.sh"

info "Inicializando Terraform dev"

terraform -chdir="${DEV_DIR}" init -reconfigure
terraform -chdir="${DEV_DIR}" validate

readonly API_BOOTSTRAP_TAG="1a2234ce4c30-amd64"
readonly WORKER_BOOTSTRAP_TAG="15d1ac428489-amd64"
readonly ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

info "Comprobando repositorios ECR"

ECR_STATE="$(
  terraform -chdir="${DEV_DIR}" state list 2>/dev/null ||
  true
)"

if ! grep -q '^module\.ecr\.' <<<"${ECR_STATE}"; then
  terraform -chdir="${DEV_DIR}" plan \
    -target=module.ecr \
    -out=ecr-bootstrap.tfplan

  terraform -chdir="${DEV_DIR}" show \
    -no-color ecr-bootstrap.tfplan |
    grep -Fq \
      "Plan: 4 to add, 0 to change, 0 to destroy." ||
    die "El plan ECR no contiene cuatro creaciones limpias."

  terraform -chdir="${DEV_DIR}" apply \
    ecr-bootstrap.tfplan
else
  info "ECR ya está administrado por Terraform"
fi

info "Autenticando Docker en ECR"

TEMP_DOCKER_CONFIG="$(mktemp -d /tmp/ticketflow-docker.XXXXXX)"
export DOCKER_CONFIG="${TEMP_DOCKER_CONFIG}"

aws ecr get-login-password \
  --region "${REGION}" |
docker login \
  --username AWS \
  --password-stdin "${ECR_REGISTRY}"

publish_bootstrap_image() {
  local name="$1"
  local context="$2"
  local tag="$3"
  local repository="ticketflow-dev-${name}"
  local local_image="ticketflow-${name}:${tag}"
  local remote_image="${ECR_REGISTRY}/${repository}:${tag}"

  if aws ecr describe-images \
    --repository-name "${repository}" \
    --image-ids imageTag="${tag}" >/dev/null 2>&1
  then
    info "La imagen ya existe: ${remote_image}"
    return
  fi

  info "Validando Dockerfile de ${name}"

  docker build \
    --check \
    --file "${context}/Dockerfile" \
    "${context}"

  info "Construyendo ${name}"

  docker build \
    --platform linux/amd64 \
    --provenance=false \
    --sbom=false \
    --tag "${local_image}" \
    --file "${context}/Dockerfile" \
    "${context}"

  info "Escaneando ${name}"

  trivy image \
    --scanners vuln \
    --severity HIGH,CRITICAL \
    --ignore-unfixed \
    --skip-version-check \
    --exit-code 1 \
    "${local_image}"

  info "Publicando ${name}"

  docker tag \
    "${local_image}" \
    "${remote_image}"

  docker push "${remote_image}"
}

publish_bootstrap_image \
  api \
  services/ticket-api \
  "${API_BOOTSTRAP_TAG}"

publish_bootstrap_image \
  worker \
  services/ticket-worker \
  "${WORKER_BOOTSTRAP_TAG}"

plan_must_not_destroy() {
  local plan_file="$1"

  terraform -chdir="${DEV_DIR}" show \
    -json "${plan_file}" |
  jq -e '
    [
      .resource_changes[]?
      | select(.change.actions | index("delete"))
    ]
    | length == 0
  ' >/dev/null ||
    die "El plan ${plan_file} contiene destrucciones."
}

plan_resource_change_count() {
  local plan_file="$1"

  terraform -chdir="${DEV_DIR}" show \
    -json "${plan_file}" |
  jq '
    [
      .resource_changes[]?
      | select(.change.actions != ["no-op"])
    ]
    | length
  '
}

confirm_apply() {
  local description="$1"
  local confirmation

  printf '\nEscribí APPLY para %s: ' "${description}"
  read -r confirmation

  [[ "${confirmation}" == "APPLY" ]] ||
    die "Aplicación cancelada por el usuario."
}

info "Planificando infraestructura principal"

terraform -chdir="${DEV_DIR}" plan \
  -target=module.networking \
  -target=module.security_groups \
  -target=module.rds \
  -target=module.ec2_admin \
  -target=module.dynamodb \
  -target=module.queues \
  -target=module.lambda_audit \
  -target=module.ecr \
  -target=module.ecs_workers \
  -target=module.eks \
  -target=aws_vpc_security_group_ingress_rule.rds_from_eks_cluster \
  -out=core-dev.tfplan

plan_must_not_destroy core-dev.tfplan

if [[ "$(plan_resource_change_count core-dev.tfplan)" -gt 0 ]]; then
  confirm_apply "crear o actualizar la infraestructura principal"

  info "Aplicando infraestructura principal"

  terraform -chdir="${DEV_DIR}" apply \
    core-dev.tfplan
else
  info "La infraestructura principal ya está actualizada"
fi

info "Configurando acceso local a EKS"

TEMP_KUBECONFIG="$(mktemp /tmp/ticketflow-kubeconfig.XXXXXX)"
export KUBECONFIG="${TEMP_KUBECONFIG}"

aws eks update-kubeconfig \
  --region "${REGION}" \
  --name ticketflow-dev

kubectl wait \
  --for=condition=Ready \
  nodes \
  --all \
  --timeout=600s

info "Generando configuración runtime de la API"

# En una reconstrucción usa la imagen inicial. En una reejecución conserva la
# imagen que CD ya dejó activa para no degradar accidentalmente la API.
API_RUNTIME_IMAGE="${ECR_REGISTRY}/ticketflow-dev-api:${API_BOOTSTRAP_TAG}"

if kubectl get deployment ticketflow-api \
  --namespace ticketflow >/dev/null 2>&1
then
  CURRENT_API_IMAGE="$(
    kubectl get deployment ticketflow-api \
      --namespace ticketflow \
      --output jsonpath='{.spec.template.spec.containers[?(@.name=="api")].image}'
  )"

  if [[ -n "${CURRENT_API_IMAGE}" ]]; then
    API_RUNTIME_IMAGE="${CURRENT_API_IMAGE}"
  fi
fi

readonly API_RUNTIME_IMAGE

readonly QUEUE_URL="$(
  terraform -chdir="${DEV_DIR}" output \
    -raw ticket_generation_queue_url
)"

readonly RDS_SECRET_ARN="$(
  terraform -chdir="${DEV_DIR}" output \
    -raw rds_master_user_secret_arn
)"

readonly DATABASE_HOST="$(
  terraform -chdir="${DEV_DIR}" output \
    -raw rds_address
)"

readonly API_SECURITY_GROUP_ID="$(
  terraform -chdir="${DEV_DIR}" output \
    -raw eks_api_security_group_id
)"

readonly VPC_ID="$(
  terraform -chdir="${DEV_DIR}" output \
    -raw vpc_id
)"

cat > kubernetes/overlays/dev/runtime.env <<EOF
API_IMAGE=${API_RUNTIME_IMAGE}
AWS_REGION=${REGION}
SQS_QUEUE_URL=${QUEUE_URL}
RDS_SECRET_ARN=${RDS_SECRET_ARN}
DATABASE_HOST=${DATABASE_HOST}
DATABASE_PORT=5432
DATABASE_NAME=ticketflow
LOG_LEVEL=INFO
EKS_API_SECURITY_GROUP_ID=${API_SECURITY_GROUP_ID}
EOF

info "Instalando AWS Load Balancer Controller"

TEMP_HELM_ROOT="$(mktemp -d /tmp/ticketflow-helm.XXXXXX)"
export HELM_CONFIG_HOME="${TEMP_HELM_ROOT}/config"
export HELM_CACHE_HOME="${TEMP_HELM_ROOT}/cache"
export HELM_DATA_HOME="${TEMP_HELM_ROOT}/data"

mkdir -p -- \
  "${HELM_CONFIG_HOME}" \
  "${HELM_CACHE_HOME}" \
  "${HELM_DATA_HOME}"

helm repo add \
  eks \
  https://aws.github.io/eks-charts \
  --force-update

helm repo update

helm upgrade --install \
  aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --version 3.6.0 \
  --set clusterName=ticketflow-dev \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait \
  --timeout 5m

info "Desplegando API en Kubernetes"

if kubectl get namespace ticketflow >/dev/null 2>&1; then
  kubectl delete job \
    ticketflow-api-migration \
    --namespace ticketflow \
    --ignore-not-found
fi

kubectl apply \
  -k kubernetes/overlays/dev

kubectl wait \
  --for=condition=complete \
  job/ticketflow-api-migration \
  --namespace ticketflow \
  --timeout=300s

kubectl rollout status \
  deployment/ticketflow-api \
  --namespace ticketflow \
  --timeout=300s

info "Esperando el Application Load Balancer"

ALB_HOST=""

for ((attempt = 1; attempt <= 30; attempt++)); do
  ALB_HOST="$(
    kubectl get ingress ticketflow-api \
      --namespace ticketflow \
      --output jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
      2>/dev/null ||
      true
  )"

  if [[ -n "${ALB_HOST}" ]]; then
    break
  fi

  sleep 10
done

[[ -n "${ALB_HOST}" ]] ||
  die "El Ingress no recibió un hostname de ALB."

curl \
  --fail \
  --retry 12 \
  --retry-delay 10 \
  "http://${ALB_HOST}/health/ready"

info "Creando frontend y acceso OIDC"

terraform -chdir="${DEV_DIR}" plan \
  -target=module.frontend \
  -target=module.github_oidc \
  -out=frontend-oidc.tfplan

plan_must_not_destroy frontend-oidc.tfplan

if [[ "$(plan_resource_change_count frontend-oidc.tfplan)" -gt 0 ]]; then
  confirm_apply "crear o actualizar frontend y OIDC"

  terraform -chdir="${DEV_DIR}" apply \
    frontend-oidc.tfplan
else
  info "Frontend y OIDC ya están actualizados"
fi

info "Actualizando el rol OIDC de GitHub"

readonly GITHUB_ROLE_ARN="$(
  terraform -chdir="${DEV_DIR}" output \
    -raw github_actions_cd_role_arn
)"

gh variable set \
  AWS_ROLE_ARN \
  --env dev \
  --body "${GITHUB_ROLE_ARN}"

info "Guardando outputs faltantes y comprobando convergencia"

terraform -chdir="${DEV_DIR}" plan \
  -out=finalize-dev.tfplan

readonly FINAL_RESOURCE_CHANGES="$(
  terraform -chdir="${DEV_DIR}" show \
    -json finalize-dev.tfplan |
  jq '
    [
      .resource_changes[]?
      | select(.change.actions != ["no-op"])
    ]
    | length
  '
)"

[[ "${FINAL_RESOURCE_CHANGES}" -eq 0 ]] ||
  die "El plan de finalización contiene cambios reales de infraestructura."

terraform -chdir="${DEV_DIR}" apply \
  finalize-dev.tfplan

FINAL_PLAN_STATUS=0

terraform -chdir="${DEV_DIR}" plan \
  -detailed-exitcode \
  -no-color >/tmp/ticketflow-final-plan.txt ||
  FINAL_PLAN_STATUS=$?

case "${FINAL_PLAN_STATUS}" in
  0)
    info "Terraform no presenta cambios"
    ;;
  2)
    cat /tmp/ticketflow-final-plan.txt
    die "Terraform todavía presenta cambios después del bootstrap."
    ;;
  *)
    cat /tmp/ticketflow-final-plan.txt
    die "Terraform no pudo generar el plan final."
    ;;
esac

info "Bootstrap terminado"

git status --short --untracked-files=all

printf '\nSiguiente paso:\n'
printf '  1. Revisar los cambios con git diff.\n'
printf '  2. Ejecutar los controles locales.\n'
printf '  3. Crear el commit de migración.\n'
printf '  4. Ejecutar git push.\n'
printf '\nEl push iniciará CI y luego CD automáticamente.\n'
printf 'Para conservar acceso kubectl local, ejecutá después:\n'
printf '  aws eks update-kubeconfig --region %s --name ticketflow-dev\n' "${REGION}"
