"""API HTTP de TicketFlow ejecutada en Amazon EKS."""

import logging
from uuid import UUID

from fastapi import FastAPI, HTTPException, status

from ticket_api.database import database_is_ready
from ticket_api.models import (
    HealthResponse,
    ReservationCreate,
    ReservationResponse,
)
from ticket_api.service import create_reservation, get_reservation

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="TicketFlow API",
    version="1.0.0",
)


@app.get("/health/live", response_model=HealthResponse)
def liveness() -> HealthResponse:
    """Confirma que el proceso HTTP continúa funcionando."""

    return HealthResponse(status="ok")


@app.get("/health/ready", response_model=HealthResponse)
def readiness() -> HealthResponse:
    """Confirma que la API puede comunicarse con PostgreSQL."""

    try:
        if not database_is_ready():
            raise RuntimeError("PostgreSQL no respondió")
    except Exception:
        logger.exception("readiness_check_failed")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="database unavailable",
        )

    return HealthResponse(status="ready")


@app.post(
    "/api/v1/reservations",
    response_model=ReservationResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def create(request: ReservationCreate) -> ReservationResponse:
    """Crea una reserva y encola la generación de su ticket."""

    try:
        reservation = create_reservation(request)
    except Exception:
        logger.exception("reservation_creation_failed")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="reservation could not be created",
        )

    logger.info(
        "reservation_created reservation_id=%s",
        reservation.reservation_id,
    )
    return reservation


@app.get(
    "/api/v1/reservations/{reservation_id}",
    response_model=ReservationResponse,
)
def get(reservation_id: UUID) -> ReservationResponse:
    """Devuelve una reserva o responde 404."""

    reservation = get_reservation(reservation_id)

    if reservation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="reservation not found",
        )

    return reservation