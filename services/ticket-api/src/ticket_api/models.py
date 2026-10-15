"""Contratos HTTP públicos de TicketFlow."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class ReservationCreate(BaseModel):
    """Datos recibidos para crear una reserva."""

    customer_name: str = Field(min_length=2, max_length=120)
    customer_email: str = Field(min_length=5, max_length=254)
    event_name: str = Field(min_length=2, max_length=160)
    quantity: int = Field(ge=1, le=10)


class ReservationResponse(BaseModel):
    """Reserva persistida y devuelta al cliente."""

    reservation_id: UUID
    customer_name: str
    customer_email: str
    event_name: str
    quantity: int
    status: str
    created_at: datetime


class HealthResponse(BaseModel):
    """Respuesta utilizada por Kubernetes para comprobar salud."""

    status: str