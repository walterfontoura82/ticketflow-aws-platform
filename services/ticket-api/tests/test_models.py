import unittest

from pydantic import ValidationError

from ticket_api.models import ReservationCreate


class ReservationCreateTests(unittest.TestCase):
    def test_accepts_valid_reservation(self):
        reservation = ReservationCreate(
            customer_name="Walter Fontoura",
            customer_email="walter@example.com",
            event_name="AWS Architecture Day",
            quantity=2,
        )

        self.assertEqual(reservation.quantity, 2)

    def test_rejects_zero_quantity(self):
        with self.assertRaises(ValidationError):
            ReservationCreate(
                customer_name="Walter Fontoura",
                customer_email="walter@example.com",
                event_name="AWS Architecture Day",
                quantity=0,
            )

    def test_rejects_quantity_above_limit(self):
        with self.assertRaises(ValidationError):
            ReservationCreate(
                customer_name="Walter Fontoura",
                customer_email="walter@example.com",
                event_name="AWS Architecture Day",
                quantity=11,
            )


if __name__ == "__main__":
    unittest.main()