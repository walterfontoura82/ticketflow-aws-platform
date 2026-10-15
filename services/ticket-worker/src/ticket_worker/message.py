"""Validación de mensajes recibidos desde Amazon SQS."""

import json
from dataclasses import dataclass
from typing import Any


class InvalidMessageError(ValueError):
    """Indica que el mensaje no cumple el contrato esperado."""


@dataclass(frozen=True)
class TicketGenerationRequest:
    """Evento que solicita generar una entrada para una reserva."""

    reservation_id: str
    requested_at: str | None = None

    @classmethod
    def from_json(cls, raw_message: str) -> "TicketGenerationRequest":
        """
        Convierte el body de SQS en un objeto validado.

        El worker solo acepta el tipo de evento que sabe procesar. Esto evita
        interpretar silenciosamente mensajes enviados a la cola equivocada.
        """
        try:
            payload: Any = json.loads(raw_message)
        except json.JSONDecodeError as error:
            raise InvalidMessageError("El body no contiene JSON válido.") from error

        if not isinstance(payload, dict):
            raise InvalidMessageError("El body debe ser un objeto JSON.")

        if payload.get("eventType") != "TicketGenerationRequested":
            raise InvalidMessageError(
                "eventType debe ser TicketGenerationRequested."
            )

        reservation_id = payload.get("reservationId")

        if not isinstance(reservation_id, str) or not reservation_id.strip():
            raise InvalidMessageError(
                "reservationId debe ser un string no vacío."
            )

        requested_at = payload.get("requestedAt")

        if requested_at is not None and not isinstance(requested_at, str):
            raise InvalidMessageError(
                "requestedAt debe ser un string cuando está presente."
            )

        return cls(
            reservation_id=reservation_id.strip(),
            requested_at=requested_at,
        )