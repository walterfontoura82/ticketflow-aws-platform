import { useState } from 'react'
import type { FormEvent } from 'react'
import './App.css'

type Reservation = {
  reservation_id: string
  customer_name: string
  customer_email: string
  event_name: string
  quantity: number
  status: string
  created_at: string
}

function App() {
  const [loading, setLoading] = useState(false)
  const [reservation, setReservation] = useState<Reservation | null>(null)
  const [error, setError] = useState('')

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setLoading(true)
    setError('')
    setReservation(null)

    const formElement = event.currentTarget
    const form = new FormData(formElement)

    try {
      const response = await fetch('/api/v1/reservations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          customer_name: form.get('customer_name'),
          customer_email: form.get('customer_email'),
          event_name: form.get('event_name'),
          quantity: Number(form.get('quantity')),
        }),
      })

      if (!response.ok) {
        throw new Error(`La API respondió ${response.status}`)
      }

      setReservation(await response.json())
      formElement.reset()
    } catch (requestError) {
      setError(
        requestError instanceof Error
          ? requestError.message
          : 'No se pudo crear la reserva',
      )
    } finally {
      setLoading(false)
    }
  }

  return (
    <main>
      <section className="hero">
        <div className="eyebrow">TICKETFLOW · AWS PLATFORM</div>
        <h1>Reservá tu próxima experiencia.</h1>
        <p>
          Una plataforma distribuida construida con EKS, RDS, SQS,
          ECS Fargate, DynamoDB y Lambda.
        </p>

        <div className="architecture">
          <span>React</span><b>→</b>
          <span>EKS</span><b>→</b>
          <span>RDS</span><b>→</b>
          <span>SQS</span><b>→</b>
          <span>Fargate</span>
        </div>
      </section>

      <section className="card">
        <div>
          <p className="section-label">NUEVA RESERVA</p>
          <h2>Generá tu entrada</h2>
          <p className="muted">
            El ticket será procesado de forma asíncrona.
          </p>
        </div>

        <form onSubmit={submit}>
          <label>
            Nombre
            <input name="customer_name" minLength={2} required />
          </label>

          <label>
            Email
            <input name="customer_email" type="email" required />
          </label>

          <label>
            Evento
            <input name="event_name" minLength={2} required />
          </label>

          <label>
            Cantidad
            <input
              name="quantity"
              type="number"
              min="1"
              max="10"
              defaultValue="1"
              required
            />
          </label>

          <button disabled={loading}>
            {loading ? 'Procesando…' : 'Confirmar reserva'}
          </button>
        </form>

        {error && <div className="message error">{error}</div>}

        {reservation && (
          <div className="message success">
            <strong>Reserva encolada correctamente</strong>
            <span>ID: {reservation.reservation_id}</span>
            <span>Estado: {reservation.status}</span>
          </div>
        )}
      </section>
    </main>
  )
}

export default App