"""Tests del ciclo de recepción y confirmación de mensajes SQS."""

import unittest
from unittest.mock import Mock

from ticket_worker.config import WorkerConfig
from ticket_worker.processor import ProcessingResult
from ticket_worker.worker import TicketWorker


def _config() -> WorkerConfig:
    return WorkerConfig(
        aws_region="us-east-1",
        queue_url="https://sqs.example/ticket-generation",
        dynamodb_table_name="ticketflow-dev-application",
        wait_time_seconds=20,
        idle_sleep_seconds=1,
        log_level="INFO",
    )


def _sqs_message(body: str) -> dict:
    return {
        "MessageId": "message-001",
        "ReceiptHandle": "receipt-handle",
        "Body": body,
        "Attributes": {
            "ApproximateReceiveCount": "1",
        },
    }


class TicketWorkerTests(unittest.TestCase):
    def test_returns_false_when_queue_is_empty(self):
        sqs = Mock()
        sqs.receive_message.return_value = {}
        processor = Mock()

        worker = TicketWorker(sqs, processor, _config())

        self.assertFalse(worker.run_once())
        processor.process.assert_not_called()
        sqs.delete_message.assert_not_called()

    def test_deletes_message_after_successful_processing(self):
        sqs = Mock()
        sqs.receive_message.return_value = {
            "Messages": [
                _sqs_message(
                    """
                    {
                      "eventType": "TicketGenerationRequested",
                      "reservationId": "reservation-123"
                    }
                    """
                )
            ]
        }

        processor = Mock()
        processor.process.return_value = ProcessingResult(
            reservation_id="reservation-123",
            ticket_id="ticket-123",
            already_completed=False,
        )

        worker = TicketWorker(sqs, processor, _config())

        self.assertTrue(worker.run_once())

        processor.process.assert_called_once()
        sqs.delete_message.assert_called_once_with(
            QueueUrl="https://sqs.example/ticket-generation",
            ReceiptHandle="receipt-handle",
        )

    def test_does_not_delete_invalid_message(self):
        sqs = Mock()
        sqs.receive_message.return_value = {
            "Messages": [
                _sqs_message("{invalid-json"),
            ]
        }
        processor = Mock()

        worker = TicketWorker(sqs, processor, _config())

        self.assertTrue(worker.run_once())
        processor.process.assert_not_called()
        sqs.delete_message.assert_not_called()

    def test_does_not_delete_message_when_processing_fails(self):
        sqs = Mock()
        sqs.receive_message.return_value = {
            "Messages": [
                _sqs_message(
                    """
                    {
                      "eventType": "TicketGenerationRequested",
                      "reservationId": "reservation-123"
                    }
                    """
                )
            ]
        }

        processor = Mock()
        processor.process.side_effect = RuntimeError(
            "simulated failure"
        )

        worker = TicketWorker(sqs, processor, _config())

        self.assertTrue(worker.run_once())
        sqs.delete_message.assert_not_called()


if __name__ == "__main__":
    unittest.main()