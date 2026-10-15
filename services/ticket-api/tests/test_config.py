import os
import unittest
from unittest.mock import patch

from pydantic import ValidationError

from ticket_api.config import get_settings


class SettingsTests(unittest.TestCase):
    def tearDown(self):
        get_settings.cache_clear()

    def test_loads_required_environment(self):
        environment = {
            "SQS_QUEUE_URL": "https://sqs.example/queue",
            "RDS_SECRET_ARN": "arn:aws:secretsmanager:us-east-1:123:secret:test",
            "DATABASE_HOST": "postgres.internal",
        }

        with patch.dict(os.environ, environment, clear=True):
            get_settings.cache_clear()
            settings = get_settings()

        self.assertEqual(settings.database_name, "ticketflow")
        self.assertEqual(settings.database_port, 5432)

    def test_rejects_missing_required_values(self):
        with patch.dict(os.environ, {}, clear=True):
            get_settings.cache_clear()
            with self.assertRaises(ValidationError):
                get_settings()


if __name__ == "__main__":
    unittest.main()