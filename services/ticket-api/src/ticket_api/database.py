"""Conexión segura a PostgreSQL usando credenciales de Secrets Manager."""

import json
from functools import lru_cache
from typing import Any

import boto3
import psycopg
from psycopg.rows import dict_row

from ticket_api.config import Settings, get_settings


@lru_cache
def _load_credentials(secret_arn: str, aws_region: str) -> dict[str, str]:
    """Obtiene y mantiene en memoria las credenciales administradas por RDS."""

    client = boto3.client("secretsmanager", region_name=aws_region)
    response = client.get_secret_value(SecretId=secret_arn)
    secret = json.loads(response["SecretString"])

    if not secret.get("username") or not secret.get("password"):
        raise RuntimeError("El secreto RDS no contiene username y password")

    return secret


def connect(settings: Settings | None = None) -> psycopg.Connection[Any]:
    """Abre una conexión TLS. La contraseña nunca aparece en variables de entorno."""

    config = settings or get_settings()
    credentials = _load_credentials(
        config.rds_secret_arn,
        config.aws_region,
    )

    return psycopg.connect(
        host=config.database_host,
        port=config.database_port,
        dbname=config.database_name,
        user=credentials["username"],
        password=credentials["password"],
        sslmode="require",
        connect_timeout=5,
        application_name="ticketflow-api",
        row_factory=dict_row,
    )


def database_is_ready() -> bool:
    """Comprueba que PostgreSQL acepta consultas."""

    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            return cursor.fetchone() is not None