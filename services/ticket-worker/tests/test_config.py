"""Tests de configuración del worker."""

import os
import unittest
from unittest.mock import patch

from ticket_worker.config import (
    ConfigurationError,
    WorkerConfig,
)


class WorkerConfigTests(unittest.TestCase):
    def test_loads_required_values_and_defaults(self):
        environment = {
            "SQS_QUEUE_URL": "https://sqs.example/queue",
            "DYNAMODB_TABLE_NAME": "ticketflow-dev-application",
        }

        with patch.dict(os.environ, environment, clear=True):
            config = WorkerConfig.from_environment()

        self.assertEqual(config.aws_region, "us-east-1")
        self.assertEqual(config.queue_url, "https://sqs.example/queue")
        self.assertEqual(
            config.dynamodb_table_name,
            "ticketflow-dev-application",
        )
        self.assertEqual(config.wait_time_seconds, 20)
        self.assertEqual(config.idle_sleep_seconds, 1)
        self.assertEqual(config.log_level, "INFO")

    def test_rejects_missing_queue_url(self):
        environment = {
            "DYNAMODB_TABLE_NAME": "ticketflow-dev-application",
        }

        with patch.dict(os.environ, environment, clear=True):
            with self.assertRaisesRegex(
                ConfigurationError,
                "SQS_QUEUE_URL",
            ):
                WorkerConfig.from_environment()

    def test_rejects_missing_table_name(self):
        environment = {
            "SQS_QUEUE_URL": "https://sqs.example/queue",
        }

        with patch.dict(os.environ, environment, clear=True):
            with self.assertRaisesRegex(
                ConfigurationError,
                "DYNAMODB_TABLE_NAME",
            ):
                WorkerConfig.from_environment()

    def test_rejects_wait_time_above_sqs_limit(self):
        environment = {
            "SQS_QUEUE_URL": "https://sqs.example/queue",
            "DYNAMODB_TABLE_NAME": "ticketflow-dev-application",
            "SQS_WAIT_TIME_SECONDS": "21",
        }

        with patch.dict(os.environ, environment, clear=True):
            with self.assertRaisesRegex(
                ConfigurationError,
                "entre 0 y 20",
            ):
                WorkerConfig.from_environment()

    def test_rejects_non_numeric_idle_sleep(self):
        environment = {
            "SQS_QUEUE_URL": "https://sqs.example/queue",
            "DYNAMODB_TABLE_NAME": "ticketflow-dev-application",
            "IDLE_SLEEP_SECONDS": "invalid",
        }

        with patch.dict(os.environ, environment, clear=True):
            with self.assertRaisesRegex(
                ConfigurationError,
                "número entero",
            ):
                WorkerConfig.from_environment()


if __name__ == "__main__":
    unittest.main()