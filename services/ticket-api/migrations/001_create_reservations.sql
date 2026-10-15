-- RDS conserva los datos transaccionales principales de cada reserva.
CREATE TABLE IF NOT EXISTS reservations (
    reservation_id UUID PRIMARY KEY,
    customer_name   VARCHAR(120) NOT NULL,
    customer_email  VARCHAR(254) NOT NULL,
    event_name      VARCHAR(160) NOT NULL,
    quantity        SMALLINT NOT NULL CHECK (quantity BETWEEN 1 AND 10),
    status          VARCHAR(32) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS reservations_created_at_idx
    ON reservations (created_at DESC);

CREATE INDEX IF NOT EXISTS reservations_customer_email_idx
    ON reservations (customer_email);