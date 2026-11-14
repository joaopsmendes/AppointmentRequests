import { useParams } from 'react-router'

function PendingRequestsPage() {
  const { nutritionistId } = useParams()

  return (
    <section>
      <h1>Pending requests</h1>
      <p>Requests of nutritionist {nutritionistId} will live here.</p>
    </section>
  )
}

export default PendingRequestsPage
