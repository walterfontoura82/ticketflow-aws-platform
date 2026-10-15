"""Tests de idempotencia y persistencia del procesador."""

import unittest
from unittest.mock import Mock

from ticket_worker.message import TicketGenerationRequest
from ticket_worker.processor import TicketProcessor


class TicketProcessorTests(unittest.TestCase):
    def test_processes_new_ticket(self):
        table = Mock()
        table.get_item.return_value = {}

        processor = TicketProcessor(table)
        result = processor.process(
            TicketGenerationRequest(
                reservation_id="reservation-123",
                requested_at="2026-10-15T12:00:00Z",
            )
        )

        self.assertEqual(result.reservation_id, "reservation-123")
        self.assertFalse(result.already_completed)
        self.assertTrue(result.ticket_id)

        table.get_item.assert_called_once_with(
            Key={
                "PK": "RESERVATION#reservation-123",
                "SK": "TICKET",
            },
            ConsistentRead=True,
        )

        self.assertEqual(table.update_item.call_count, 2)

        processing_call = table.update_item.call_args_list[0].kwargs
        completed_call = table.update_item.call_args_list[1].kwargs

        self.assertEqual(
            processing_call["ExpressionAttributeValues"][":status"],
            "PROCESSING",
        )
        self.assertEqual(
            completed_call["ExpressionAttributeValues"][":status"],
            "COMPLETED",
        )
        self.assertEqual(
            completed_call["ExpressionAttributeValues"][":ticket_id"],
            result.ticket_id,
        )

    def test_does_not_regenerate_completed_ticket(self):
        table = Mock()
        table.get_item.return_value = {
            "Item": {
                "status": "COMPLETED",
                "ticket_id": "ticket-existing",
            }
        }

        processor = TicketProcessor(table)
        result = processor.process(
            TicketGenerationRequest(
                reservation_id="reservation-123",
            )
        )

        self.assertTrue(result.already_completed)
        self.assertEqual(result.ticket_id, "ticket-existing")
        table.update_item.assert_not_called()

    def test_reprocesses_incomplete_ticket(self):
        table = Mock()
        table.get_item.return_value = {
            "Item": {
                "status": "PROCESSING",
            }
        }

        processor = TicketProcessor(table)
        result = processor.process(
            TicketGenerationRequest(
                reservation_id="reservation-retry",
            )
        )

        self.assertFalse(result.already_completed)
        self.assertEqual(table.update_item.call_count, 2)


if __name__ == "__main__":
    unittest.main()