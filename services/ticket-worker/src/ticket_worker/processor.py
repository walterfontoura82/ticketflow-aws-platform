"""Procesamiento idempotente de solicitudes de generación de entradas."""

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Protocol
from uuid import uuid4

from ticket_worker.message import TicketGenerationRequest


class DynamoDBTable(Protocol):
    """Contrato mínimo que debe cumplir una tabla DynamoDB."""

    def get_item(self, **kwargs: Any) -> dict[str, Any]:
        ...

    def update_item(self, **kwargs: Any) -> dict[str, Any]:
        ...


@dataclass(frozen=True)
class ProcessingResult:
    """Resultado utilizado para logs, métricas y tests."""

    reservation_id: str
    ticket_id: str
    already_completed: bool


def _utc_timestamp() -> str:
    """Devuelve un timestamp UTC comparable y legible."""
    return datetime.now(timezone.utc).isoformat()


class TicketProcessor:
    """Actualiza en DynamoDB el ciclo de vida de una entrada."""

    def __init__(self, table: DynamoDBTable) -> None:
        self._table = table

    def process(
        self,
        request: TicketGenerationRequest,
    ) -> ProcessingResult:
        """
        Procesa una solicitud de forma idempotente.

        Si el ticket ya está COMPLETED, devuelve el resultado existente y no
        genera otro identificador. Esto protege contra entregas repetidas de
        SQS, que ofrece semántica at-least-once.
        """
        key = {
            "PK": f"RESERVATION#{request.reservation_id}",
            "SK": "TICKET",
        }

        existing_response = self._table.get_item(
            Key=key,
            ConsistentRead=True,
        )
        existing_item = existing_response.get("Item", {})

        if existing_item.get("status") == "COMPLETED":
            return ProcessingResult(
                reservation_id=request.reservation_id,
                ticket_id=existing_item["ticket_id"],
                already_completed=True,
            )

        processing_timestamp = _utc_timestamp()

        self._table.update_item(
            Key=key,
            UpdateExpression=(
                "SET #status = :status, "
                "updated_at = :updated_at, "
                "requested_at = :requested_at, "
                "GSI1PK = :gsi1pk, "
                "GSI1SK = :gsi1sk"
            ),
            ExpressionAttributeNames={
                "#status": "status",
            },
            ExpressionAttributeValues={
                ":status": "PROCESSING",
                ":updated_at": processing_timestamp,
                ":requested_at": (
                    request.requested_at or processing_timestamp
                ),
                ":gsi1pk": "TICKET_STATUS#PROCESSING",
                ":gsi1sk": (
                    f"{processing_timestamp}"
                    f"#RESERVATION#{request.reservation_id}"
                ),
            },
        )


        #Este identificador representa la entrada generada. Cuando agreguemos
        #S3, aquí se producirá el archivo y se guardará su object key.

        ticket_id = str(uuid4())
        completed_timestamp = _utc_timestamp()

        self._table.update_item(
            Key=key,
            UpdateExpression=(
                "SET #status = :status, "
                "ticket_id = :ticket_id, "
                "updated_at = :updated_at, "
                "GSI1PK = :gsi1pk, "
                "GSI1SK = :gsi1sk"
            ),
            ExpressionAttributeNames={
                "#status": "status",
            },
            ExpressionAttributeValues={
                ":status": "COMPLETED",
                ":ticket_id": ticket_id,
                ":updated_at": completed_timestamp,
                ":gsi1pk": "TICKET_STATUS#COMPLETED",
                ":gsi1sk": (
                    f"{completed_timestamp}"
                    f"#RESERVATION#{request.reservation_id}"
                ),
            },
        )

        return ProcessingResult(
            reservation_id=request.reservation_id,
            ticket_id=ticket_id,
            already_completed=False,
        )