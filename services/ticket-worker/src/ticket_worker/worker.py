"""Proceso principal del worker ejecutado por ECS/Fargate."""

import json
import logging
import signal
import threading
from typing import Any



from ticket_worker.config import WorkerConfig
from ticket_worker.message import (
    InvalidMessageError,
    TicketGenerationRequest,
)
from ticket_worker.processor import TicketProcessor


logger = logging.getLogger("ticket_worker")
stop_event = threading.Event()


def _log(
    level: int,
    message: str,
    **fields: Any,
) -> None:
    """Escribe una línea JSON para facilitar búsquedas en CloudWatch."""
    logger.log(
        level,
        json.dumps(
            {
                "message": message,
                **fields,
            },
            sort_keys=True,
        ),
    )


def _request_shutdown(
    signal_number: int,
    _frame: Any,
) -> None:
    """
    Solicita un apagado ordenado.

    ECS envía SIGTERM antes de detener una tarea. El worker termina el mensaje
    actual y evita comenzar otro.
    """
    _log(
        logging.INFO,
        "shutdown_requested",
        signal_number=signal_number,
    )
    stop_event.set()


class TicketWorker:
    """Realiza long polling sobre SQS y procesa un mensaje por vez."""

    def __init__(
        self,
        sqs_client: Any,
        processor: TicketProcessor,
        config: WorkerConfig,
    ) -> None:
        self._sqs = sqs_client
        self._processor = processor
        self._config = config

    def run_once(self) -> bool:
        """
        Recibe y procesa como máximo un mensaje.

        Devuelve True si SQS entregó un mensaje y False si la consulta terminó
        sin resultados.
        """
        response = self._sqs.receive_message(
            QueueUrl=self._config.queue_url,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=self._config.wait_time_seconds,
            MessageSystemAttributeNames=[
                "ApproximateReceiveCount",
            ],
        )

        messages = response.get("Messages", [])

        if not messages:
            return False

        message = messages[0]
        message_id = message.get("MessageId")
        receive_count = (
            message.get("Attributes", {})
            .get("ApproximateReceiveCount")
        )

        try:
            request = TicketGenerationRequest.from_json(
                message.get("Body", "")
            )
            result = self._processor.process(request)

            _log(
                logging.INFO,
                "ticket_processed",
                message_id=message_id,
                reservation_id=result.reservation_id,
                ticket_id=result.ticket_id,
                already_completed=result.already_completed,
                receive_count=receive_count,
            )


            # DeleteMessage solo se ejecuta después de completar correctamente
            # el procesamiento.

            self._sqs.delete_message(
                QueueUrl=self._config.queue_url,
                ReceiptHandle=message["ReceiptHandle"],
            )

        except InvalidMessageError as error:
            _log(
                logging.ERROR,
                "invalid_message",
                message_id=message_id,
                receive_count=receive_count,
                error=str(error),
            )

        except Exception:
            logger.exception(
                json.dumps(
                    {
                        "message": "message_processing_failed",
                        "message_id": message_id,
                        "receive_count": receive_count,
                    },
                    sort_keys=True,
                )
            )

        return True

    def run_forever(self) -> None:
        """Ejecuta long polling hasta que ECS solicite detener la tarea."""
        _log(logging.INFO, "worker_started")

        while not stop_event.is_set():
            message_received = self.run_once()

            if not message_received:
                stop_event.wait(
                    self._config.idle_sleep_seconds
                )

        _log(logging.INFO, "worker_stopped")


def main() -> None:
    """Construye clientes AWS usando credenciales temporales del Task Role."""
    import boto3
    config = WorkerConfig.from_environment()

    logging.basicConfig(
        level=config.log_level,
        format="%(message)s",
    )

    signal.signal(signal.SIGTERM, _request_shutdown)
    signal.signal(signal.SIGINT, _request_shutdown)

    dynamodb = boto3.resource(
        "dynamodb",
        region_name=config.aws_region,
    )
    sqs = boto3.client(
        "sqs",
        region_name=config.aws_region,
    )

    processor = TicketProcessor(
        dynamodb.Table(config.dynamodb_table_name)
    )
    worker = TicketWorker(sqs, processor, config)
    worker.run_forever()


if __name__ == "__main__":
    main()