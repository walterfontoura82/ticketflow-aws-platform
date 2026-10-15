"""Configuración de la API obtenida exclusivamente desde variables de entorno."""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Valida la configuración antes de iniciar la aplicación."""

    model_config = SettingsConfigDict(
        case_sensitive=True,
        extra="ignore",
    )

    aws_region: str = Field(default="us-east-1", alias="AWS_REGION")
    sqs_queue_url: str = Field(alias="SQS_QUEUE_URL")

    rds_secret_arn: str = Field(alias="RDS_SECRET_ARN")
    database_host: str = Field(alias="DATABASE_HOST")
    database_port: int = Field(default=5432, alias="DATABASE_PORT")
    database_name: str = Field(default="ticketflow", alias="DATABASE_NAME")

    log_level: str = Field(default="INFO", alias="LOG_LEVEL")


@lru_cache
def get_settings() -> Settings:
    """Construye la configuración una sola vez por proceso."""

    return Settings()