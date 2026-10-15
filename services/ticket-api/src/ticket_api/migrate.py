"""Ejecuta migraciones SQL antes de desplegar la API."""

from pathlib import Path

from ticket_api.database import connect


def main() -> None:
    migrations_directory = Path("/app/migrations")

    with connect() as connection:
        with connection.cursor() as cursor:
            for migration in sorted(migrations_directory.glob("*.sql")):
                cursor.execute(migration.read_text(encoding="utf-8"))
                print(f"migration_applied={migration.name}")


if __name__ == "__main__":
    main()