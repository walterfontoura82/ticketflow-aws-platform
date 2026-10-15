"""Tests del contrato de mensajes del worker."""

import unittest

from ticket_worker.message import (
    InvalidMessageError,
    TicketGenerationRequest,
)


class TicketGenerationRequestTests(unittest.TestCase):
    def test_parses_valid_message(self):
        request = TicketGenerationRequest.from_json(
            """
            {
              "eventType": "TicketGenerationRequested",
              "reservationId": "reservation-123",
              "requestedAt": "2026-10-15T12:00:00Z"
            }
            """
        )

        self.assertEqual(request.reservation_id, "reservation-123")
        self.assertEqual(request.requested_at, "2026-10-15T12:00:00Z")

    def test_rejects_invalid_json(self):
        with self.assertRaisesRegex(
            InvalidMessageError,
            "JSON válido",
        ):
            TicketGenerationRequest.from_json("{invalid-json")

    def test_rejects_non_object_json(self):
        with self.assertRaisesRegex(
            InvalidMessageError,
            "objeto JSON",
        ):
            TicketGenerationRequest.from_json('["unexpected", "list"]')

    def test_rejects_unknown_event_type(self):
        with self.assertRaisesRegex(
            InvalidMessageError,
            "eventType",
        ):
            TicketGenerationRequest.from_json(
                """
                {
                  "eventType": "UnknownEvent",
                  "reservationId": "reservation-123"
                }
                """
            )

    def test_rejects_missing_reservation_id(self):
        with self.assertRaisesRegex(
            InvalidMessageError,
            "reservationId",
        ):
            TicketGenerationRequest.from_json(
                """
                {
                  "eventType": "TicketGenerationRequested"
                }
                """
            )


if __name__ == "__main__":
    unittest.main()