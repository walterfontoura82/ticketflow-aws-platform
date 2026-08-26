"""Tests unitarios de la Lambda de auditoría.
Estos tests comprueban:
- Procesamiento de un evento realista.
- Extracción de PK y SK.
- Ausencia del contenido sensible de NewImage en logs.
- Rechazo controlado de otros orígenes.
- Manejo de un lote vacío.

"""

import json
import logging
import unittest

from handler import lambda_handler


class FakeContext:
    """Contexto mínimo que simula el objeto entregado por AWS Lambda."""

    aws_request_id = "test-request-id"


class LambdaHandlerTests(unittest.TestCase):
    def test_processes_dynamodb_stream_record(self):
        """Procesa un registro válido y escribe una auditoría estructurada."""
        event = {
            "Records": [
                {
                    "eventID": "event-001",
                    "eventName": "INSERT",
                    "eventSource": "aws:dynamodb",
                    "eventSourceARN": (
                        "arn:aws:dynamodb:us-east-1:123456789012:"
                        "table/ticketflow/stream/test"
                    ),
                    "dynamodb": {
                        "SequenceNumber": "1001",
                        "Keys": {
                            "PK": {"S": "REQUEST#123"},
                            "SK": {"S": "IDEMPOTENCY"},
                        },
                        "NewImage": {
                            "sensitive_data": {"S": "must-not-be-logged"}
                        },
                    },
                }
            ]
        }

        with self.assertLogs(level=logging.INFO) as captured_logs:
            result = lambda_handler(event, FakeContext())

        self.assertEqual(result["received_records"], 1)
        self.assertEqual(result["processed_records"], 1)

        audit_log = json.loads(captured_logs.records[0].getMessage())

        self.assertEqual(audit_log["event_name"], "INSERT")
        self.assertEqual(audit_log["keys"]["PK"], "REQUEST#123")
        self.assertEqual(audit_log["keys"]["SK"], "IDEMPOTENCY")
        self.assertEqual(
            audit_log["function_request_id"],
            "test-request-id",
        )

        self.assertNotIn(
            "must-not-be-logged",
            captured_logs.records[0].getMessage(),
        )

    def test_ignores_unsupported_event_source(self):
        """Ignora registros que no provengan de DynamoDB Streams."""
        event = {
            "Records": [
                {
                    "eventSource": "aws:s3",
                }
            ]
        }

        with self.assertLogs(level=logging.WARNING):
            result = lambda_handler(event, FakeContext())

        self.assertEqual(result["received_records"], 1)
        self.assertEqual(result["processed_records"], 0)

    def test_accepts_event_without_records(self):
        """Un evento vacío no debe producir un error."""
        result = lambda_handler({}, FakeContext())

        self.assertEqual(result["received_records"], 0)
        self.assertEqual(result["processed_records"], 0)


if __name__ == "__main__":
    unittest.main()