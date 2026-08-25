#!/usr/bin/env bash

# Prepara una cuenta sandbox nueva y reconstruye el backend de Terraform.
#
# Uso:
#   ./scripts/switch-sandbox-account.sh ACCOUNT_ID
#
# Ejemplo:
#   ./scripts/switch-sandbox-account.sh 966299413569
#
# El script:
#   1. Valida el Account ID y la identidad activa de AWS CLI.
#   2. Actualiza referencias conocidas al bucket de state.
#   3. Conserva states, planes y metadata locales de la cuenta anterior.
#   4. Crea un plan local para el bucket de state nuevo.
#   5. Pide confirmación explícita antes del apply.
#   6. Crea el bucket y migra el state local a S3.
#   7. Reinicializa y valida el ambiente dev contra el backend nuevo.
#   8. Deja los cambios sin stage ni commit para revisión humana.

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly BOOTSTRAP_DIR="${PROJECT_ROOT}/terraform/bootstrap"
readonly DEV_DIR="${PROJECT_ROOT}/terraform/environments/dev"
readonly REGION="us-east-1"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '\n==> %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontró el comando requerido: $1"
}

replace_bucket_reference() {
  local file="$1"
  local new_bucket="$2"

  [[ -f "${file}" ]] || return 0

  sed -E -i \
    "s/ticketflow-tfstate-[0-9]{12}-us-east-1/${new_bucket}/g" \
    "${file}"
}

move_if_present() {
  local source_path="$1"
  local destination_dir="$2"

  if [[ -e "${source_path}" ]]; then
    mv -- "${source_path}" "${destination_dir}/"
  fi
}

[[ $# -eq 1 ]] || die "Uso: $0 ACCOUNT_ID"

readonly NEW_ACCOUNT_ID="$1"
[[ "${NEW_ACCOUNT_ID}" =~ ^[0-9]{12}$ ]] || \
  die "El Account ID debe contener exactamente 12 dígitos."

require_command aws
require_command terraform
require_command git
require_command sed
require_command grep

[[ -f "${BOOTSTRAP_DIR}/backend.tf" ]] || \
  die "Falta terraform/bootstrap/backend.tf."
[[ -f "${BOOTSTRAP_DIR}/main.tf" ]] || \
  die "Falta terraform/bootstrap/main.tf."

info "Validando identidad AWS activa"
readonly ACTIVE_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
[[ "${ACTIVE_ACCOUNT_ID}" == "${NEW_ACCOUNT_ID}" ]] || \
  die "La cuenta activa (${ACTIVE_ACCOUNT_ID}) no coincide con ${NEW_ACCOUNT_ID}."

readonly ACTIVE_REGION="$(aws configure get region)"
[[ "${ACTIVE_REGION}" == "${REGION}" ]] || \
  die "La región activa debe ser ${REGION}; se encontró ${ACTIVE_REGION:-ninguna}."

readonly OLD_ACCOUNT_ID="$(
  sed -nE 's/.*ticketflow-tfstate-([0-9]{12})-us-east-1.*/\1/p' \
    "${BOOTSTRAP_DIR}/main.tf" | head -n 1
)"

[[ -n "${OLD_ACCOUNT_ID}" ]] || \
  die "No se pudo obtener el Account ID actual desde bootstrap/main.tf."

if [[ "${OLD_ACCOUNT_ID}" == "${NEW_ACCOUNT_ID}" ]]; then
  die "El proyecto ya referencia la cuenta ${NEW_ACCOUNT_ID}. No hay nada que migrar."
fi

readonly NEW_BUCKET="ticketflow-tfstate-${NEW_ACCOUNT_ID}-${REGION}"
readonly TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
readonly RECOVERY_DIR="${BOOTSTRAP_DIR}/.sandbox-recovery/${OLD_ACCOUNT_ID}-${TIMESTAMP}"

info "Cambio solicitado"
printf 'Cuenta anterior: %s\n' "${OLD_ACCOUNT_ID}"
printf 'Cuenta nueva:    %s\n' "${NEW_ACCOUNT_ID}"
printf 'Bucket nuevo:    %s\n' "${NEW_BUCKET}"
printf 'Recuperación:    %s\n' "${RECOVERY_DIR}"

mkdir -p -- "${RECOVERY_DIR}/bootstrap" "${RECOVERY_DIR}/dev"

info "Preservando artefactos locales anteriores"
move_if_present "${BOOTSTRAP_DIR}/.terraform" "${RECOVERY_DIR}/bootstrap"
move_if_present "${BOOTSTRAP_DIR}/terraform.tfstate" "${RECOVERY_DIR}/bootstrap"
move_if_present "${BOOTSTRAP_DIR}/terraform.tfstate.backup" "${RECOVERY_DIR}/bootstrap"

for plan_file in "${BOOTSTRAP_DIR}"/*.tfplan "${BOOTSTRAP_DIR}"/*.plan; do
  [[ -e "${plan_file}" ]] || continue
  mv -- "${plan_file}" "${RECOVERY_DIR}/bootstrap/"
done

move_if_present "${DEV_DIR}/.terraform" "${RECOVERY_DIR}/dev"
move_if_present "${DEV_DIR}/terraform.tfstate" "${RECOVERY_DIR}/dev"
move_if_present "${DEV_DIR}/terraform.tfstate.backup" "${RECOVERY_DIR}/dev"

for plan_file in "${DEV_DIR}"/*.tfplan "${DEV_DIR}"/*.plan; do
  [[ -e "${plan_file}" ]] || continue
  mv -- "${plan_file}" "${RECOVERY_DIR}/dev/"
done

info "Actualizando referencias conocidas al bucket"
replace_bucket_reference "${BOOTSTRAP_DIR}/main.tf" "${NEW_BUCKET}"
replace_bucket_reference "${BOOTSTRAP_DIR}/backend.tf" "${NEW_BUCKET}"
replace_bucket_reference "${DEV_DIR}/backend.tf" "${NEW_BUCKET}"
replace_bucket_reference "${PROJECT_ROOT}/terraform.md" "${NEW_BUCKET}"

readonly DISABLED_BACKEND="${BOOTSTRAP_DIR}/backend.tf.disabled"
mv -- "${BOOTSTRAP_DIR}/backend.tf" "${DISABLED_BACKEND}"

restore_backend_on_error() {
  if [[ -f "${DISABLED_BACKEND}" && ! -f "${BOOTSTRAP_DIR}/backend.tf" ]]; then
    mv -- "${DISABLED_BACKEND}" "${BOOTSTRAP_DIR}/backend.tf"
  fi
}
trap restore_backend_on_error ERR INT TERM

info "Inicializando bootstrap con state local"
terraform -chdir="${BOOTSTRAP_DIR}" init
terraform -chdir="${BOOTSTRAP_DIR}" validate

readonly PLAN_FILE="${RECOVERY_DIR}/bootstrap/bootstrap-${NEW_ACCOUNT_ID}.tfplan"
terraform -chdir="${BOOTSTRAP_DIR}" plan -out="${PLAN_FILE}"

terraform -chdir="${BOOTSTRAP_DIR}" show -no-color "${PLAN_FILE}" \
  | grep -Fq "Plan: 6 to add, 0 to change, 0 to destroy." \
  || die "El plan del bootstrap no contiene exactamente seis creaciones limpias."

info "Revisión obligatoria"
printf 'El plan debe indicar: 6 to add, 0 to change, 0 to destroy.\n'
printf 'Plan guardado en: %s\n' "${PLAN_FILE}"
printf '\nEscribí CREATE para crear el bucket de state en la cuenta %s: ' "${NEW_ACCOUNT_ID}"
read -r CONFIRMATION
[[ "${CONFIRMATION}" == "CREATE" ]] || die "Operación cancelada por el usuario."

info "Creando backend S3 nuevo"
terraform -chdir="${BOOTSTRAP_DIR}" apply "${PLAN_FILE}"

mv -- "${DISABLED_BACKEND}" "${BOOTSTRAP_DIR}/backend.tf"
trap - ERR INT TERM

info "Migrando state local al backend S3"
terraform -chdir="${BOOTSTRAP_DIR}" init -migrate-state -force-copy
terraform -chdir="${BOOTSTRAP_DIR}" validate

info "Comprobando que el bootstrap no tenga cambios pendientes en AWS"
terraform -chdir="${BOOTSTRAP_DIR}" plan -detailed-exitcode || {
  status=$?
  [[ ${status} -eq 2 ]] && die "El bootstrap todavía presenta cambios. Revisalos manualmente."
  exit "${status}"
}

info "Reinicializando el ambiente dev con el backend nuevo"
terraform -chdir="${DEV_DIR}" init -reconfigure
terraform -chdir="${DEV_DIR}" validate

info "Aplicando formato y mostrando archivos modificados"
terraform fmt -recursive "${PROJECT_ROOT}/terraform"
git -C "${PROJECT_ROOT}" status --short --untracked-files=all

printf '\nMigración terminada.\n'
printf 'No se ejecutaron git add ni git commit.\n'
printf 'Revisá los cambios y generá un plan de dev antes de crear la red.\n'
