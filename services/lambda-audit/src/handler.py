"""
Lambda de auditoría para eventos de DynamoDB Streams.

La función registra metadatos del cambio, pero no imprime NewImage ni OldImage.
Así evitamos enviar información potencialmente sensible a CloudWatch Logs.

Qué hace cada parte:
- _deserialize_key: interpreta el formato tipado de DynamoDB.
- _extract_keys: extrae únicamente las claves del elemento.
- lambda_handler: punto de entrada que AWS invoca.
- Cada evento se registra como JSON para poder consultarlo en CloudWatch Logs.
- No registra NewImage ni OldImage, evitando exponer el contenido completo.
- La función no necesita credenciales en el código; AWS le entregará un rol IAM.

"""

import json
import logging
import os
from typing import Any


logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO").upper())


def _deserialize_key(attribute: dict[str, Any]) -> Any:
    """
    Convierte un AttributeValue de DynamoDB a un valor sencillo.

    Las claves de TicketFlow normalmente serán strings, pero contemplamos
    otros tipos para que el registro de auditoría sea robusto.
    """
    if "S" in attribute:
        return attribute["S"]

    if "N" in attribute:
        return attribute["N"]

    if "B" in attribute:
        return "<binary>"

    if "BOOL" in attribute:
        return attribute["BOOL"]

    if "NULL" in attribute:
        return None

    return "<unsupported>"


def _extract_keys(keys: dict[str, dict[str, Any]]) -> dict[str, Any]:
    """Extrae PK, SK u otras claves sin registrar el contenido del elemento."""
    return {
        name: _deserialize_key(value)
        for name, value in keys.items()
    }


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, int]:
    """
    Procesa un lote entregado por DynamoDB Streams.

    DynamoDB Streams puede entregar varios registros en una misma invocación.
    Cada registro se escribe como una línea JSON independiente para facilitar
    búsquedas y métricas en CloudWatch Logs.
    """
    records = event.get("Records", [])
    processed_records = 0

    for record in records:
        if record.get("eventSource") != "aws:dynamodb":
            logger.warning(
                json.dumps(
                    {
                        "message": "unsupported_event_source",
                        "event_source": record.get("eventSource"),
                    }
                )
            )
            continue

        dynamodb_record = record.get("dynamodb", {})

        audit_event = {
            "message": "dynamodb_change_audited",
            "event_id": record.get("eventID"),
            "event_name": record.get("eventName"),
            "event_source_arn": record.get("eventSourceARN"),
            "sequence_number": dynamodb_record.get("SequenceNumber"),
            "keys": _extract_keys(dynamodb_record.get("Keys", {})),
            "function_request_id": getattr(context, "aws_request_id", None),
        }

        logger.info(json.dumps(audit_event, sort_keys=True))
        processed_records += 1

    return {
        "processed_records": processed_records,
        "received_records": len(records),
    }