import { Link } from 'react-router'

function NotFoundPage() {
  return (
    <section className="mx-auto max-w-5xl px-4 py-8">
      <h1>Page not found</h1>
      <Link to="/">Back to the search</Link>
    </section>
  )
}

export default NotFoundPage
