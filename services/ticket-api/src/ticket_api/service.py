"""Casos de uso de reservas y publicación asíncrona en SQS."""

import json
from datetime import datetime, timezone
from typing import Any
from uuid import UUID, uuid4

import boto3

from ticket_api.config import Settings, get_settings
from ticket_api.database import connect
from ticket_api.models import ReservationCreate, ReservationResponse


def _update_status(
    reservation_id: UUID,
    status: str,
    settings: Settings,
) -> None:
    with connect(settings) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE reservations
                SET status = %s
                WHERE reservation_id = %s
                """,
                (status, reservation_id),
            )


def create_reservation(
    request: ReservationCreate,
    settings: Settings | None = None,
    sqs_client: Any | None = None,
) -> ReservationResponse:
    """Persiste la reserva y solicita la generación asíncrona del ticket."""

    config = settings or get_settings()
    reservation_id = uuid4()
    created_at = datetime.now(timezone.utc)

    with connect(config) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO reservations (
                    reservation_id,
                    customer_name,
                    customer_email,
                    event_name,
                    quantity,
                    status,
                    created_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                RETURNING *
                """,
                (
                    reservation_id,
                    request.customer_name,
                    request.customer_email,
                    request.event_name,
                    request.quantity,
                    "PENDING",
                    created_at,
                ),
            )
            reservation = cursor.fetchone()

    client = sqs_client or boto3.client(
        "sqs",
        region_name=config.aws_region,
    )

    try:
        client.send_message(
            QueueUrl=config.sqs_queue_url,
            MessageBody=json.dumps(
                {
                    "eventType": "TicketGenerationRequested",
                    "reservationId": str(reservation_id),
                    "requestedAt": created_at.isoformat(),
                }
            ),
        )
        _update_status(reservation_id, "QUEUED", config)
        reservation["status"] = "QUEUED"
    except Exception:
        _update_status(reservation_id, "QUEUE_FAILED", config)
        raise

    return ReservationResponse.model_validate(reservation)


def get_reservation(reservation_id: UUID) -> ReservationResponse | None:
    """Consulta una reserva mediante su identificador."""

    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT *
                FROM reservations
                WHERE reservation_id = %s
                """,
                (reservation_id,),
            )
            reservation = cursor.fetchone()

    if reservation is None:
        return None

    return ReservationResponse.model_validate(reservation)