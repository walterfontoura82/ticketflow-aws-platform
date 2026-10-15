# syntax=docker/dockerfile:1

# Etapa de build: instala dependencias fuera de la imagen final.
FROM python:3.12.12-slim-bookworm AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

COPY requirements.txt .

RUN python -m pip install \
    --prefix=/install \
    --requirement requirements.txt


# Etapa de runtime: contiene solamente Python, dependencias y aplicación.
FROM python:3.12.12-slim-bookworm AS runtime

LABEL org.opencontainers.image.title="TicketFlow ticket worker" \
      org.opencontainers.image.description="Worker ECS/Fargate para generación asíncrona de entradas" \
      org.opencontainers.image.source="https://github.com/walterfontoura82/ticketflow-aws-platform"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app
# Instala las actualizaciones de seguridad disponibles para la imagen base.
# La limpieza evita conservar índices de APT en la imagen final.
RUN apt-get update \
    && apt-get upgrade --yes \
    && rm -rf /var/lib/apt/lists/*


# La aplicación no debe ejecutarse como root. UID/GID fijo facilita políticas
# de seguridad y mantiene el mismo usuario en distintos ambientes.

RUN groupadd --system --gid 10001 ticketflow \
    && useradd \
        --system \
        --uid 10001 \
        --gid ticketflow \
        --home-dir /nonexistent \
        --shell /usr/sbin/nologin \
        ticketflow

WORKDIR /app

COPY --from=builder /install /usr/local
COPY src/ticket_worker ./ticket_worker

USER 10001:10001

CMD ["python", "-m", "ticket_worker.worker"]