"""Configuración del worker obtenida desde variables de entorno."""

import os
from dataclasses import dataclass


class ConfigurationError(ValueError):
    """Indica que falta una variable obligatoria o tiene un valor inválido."""


def _required_environment_variable(name: str) -> str:
    value = os.getenv(name, "").strip()

    if not value:
        raise ConfigurationError(
            f"La variable de entorno {name} es obligatoria."
        )

    return value


def _integer_environment_variable(
    name: str,
    default: int,
    minimum: int,
    maximum: int,
) -> int:
    raw_value = os.getenv(name, str(default))

    try:
        value = int(raw_value)
    except ValueError as error:
        raise ConfigurationError(
            f"La variable {name} debe ser un número entero."
        ) from error

    if value < minimum or value > maximum:
        raise ConfigurationError(
            f"La variable {name} debe estar entre {minimum} y {maximum}."
        )

    return value


@dataclass(frozen=True)
class WorkerConfig:
    """Configuración inmutable utilizada durante toda la ejecución."""

    aws_region: str
    queue_url: str
    dynamodb_table_name: str
    wait_time_seconds: int
    idle_sleep_seconds: int
    log_level: str

    @classmethod
    def from_environment(cls) -> "WorkerConfig":
        """
        Carga la configuración al iniciar el contenedor.

        La aplicación falla inmediatamente si falta un valor obligatorio,
        evitando mantener una tarea ECS activa pero incapaz de trabajar.
        """
        return cls(
            aws_region=os.getenv("AWS_REGION", "us-east-1"),
            queue_url=_required_environment_variable("SQS_QUEUE_URL"),
            dynamodb_table_name=_required_environment_variable(
                "DYNAMODB_TABLE_NAME"
            ),
            wait_time_seconds=_integer_environment_variable(
                "SQS_WAIT_TIME_SECONDS",
                default=20,
                minimum=0,
                maximum=20,
            ),
            idle_sleep_seconds=_integer_environment_variable(
                "IDLE_SLEEP_SECONDS",
                default=1,
                minimum=0,
                maximum=60,
            ),
            log_level=os.getenv("LOG_LEVEL", "INFO").upper(),
        )