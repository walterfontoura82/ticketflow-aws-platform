#!/usr/bin/env bash

# Empaqueta la Lambda de auditoría de forma reproducible.
#
# Antes de generar el ZIP ejecuta los tests. Si un test falla, el script se
# detiene y conserva el artefacto anterior sin desplegar código defectuoso.

set -Eeuo pipefail

readonly SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
  pwd
)"
readonly REPOSITORY_ROOT="$(
  cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1
  pwd
)"

readonly LAMBDA_ROOT="${REPOSITORY_ROOT}/services/lambda-audit"
readonly SOURCE_DIR="${LAMBDA_ROOT}/src"
readonly TESTS_DIR="${LAMBDA_ROOT}/tests"
readonly BUILD_DIR="${LAMBDA_ROOT}/build"
readonly PACKAGE_FILE="${BUILD_DIR}/lambda-audit.zip"

command -v python3 >/dev/null 2>&1 || {
  echo "Error: python3 no está instalado." >&2
  exit 1
}

command -v zip >/dev/null 2>&1 || {
  echo "Error: zip no está instalado." >&2
  exit 1
}

echo "==> Ejecutando tests unitarios"
PYTHONPATH="${SOURCE_DIR}" \
  python3 -m unittest discover \
  -s "${TESTS_DIR}" \
  -p 'test_*.py' \
  -v

echo "==> Generando paquete Lambda"
mkdir -p "${BUILD_DIR}"

(
  cd "${SOURCE_DIR}"
  zip -q -FS "${PACKAGE_FILE}" handler.py
)

echo "==> Verificando paquete"
unzip -tq "${PACKAGE_FILE}"

echo "==> SHA-256"
sha256sum "${PACKAGE_FILE}"

echo "Paquete generado: ${PACKAGE_FILE}"