import { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { searchNutritionists } from '../api/nutritionists'
import Avatar from '../components/Avatar'
import Pagination from '../components/Pagination'

const PER_PAGE = 10

function ProfessionalsPage() {
  const [page, setPage] = useState(1)

  const [result, setResult] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    let ignore = false

    async function loadNutritionists() {
      setIsLoading(true)
      setError(null)
      try {
        const response = await searchNutritionists({ page, perPage: PER_PAGE })
        if (!ignore) setResult(response)
      } catch (requestError) {
        if (!ignore) setError(requestError)
      } finally {
        if (!ignore) setIsLoading(false)
      }
    }

    loadNutritionists()

    return () => {
      ignore = true
    }
  }, [page])

  return (
    <section className="mx-auto max-w-5xl px-4 py-8">
      <h1 className="text-xl text-slate-800">Choose your profile</h1>
      <p className="mb-6 text-sm text-slate-500">See and answer the appointment requests you received</p>

      {isLoading && <p className="text-slate-500">Loading nutritionists...</p>}

      {!isLoading && error && (
        <p className="rounded bg-red-50 p-4 text-red-700">Could not load the nutritionists. Please try again.</p>
      )}

      {!isLoading && !error && result && (
        <>
          <ul className="divide-y divide-slate-100 rounded bg-white shadow-sm">
            {result.data.map((nutritionist) => (
              <li key={nutritionist.id}>
                <Link
                  to={`/nutritionists/${nutritionist.id}/requests`}
                  className="flex items-center gap-4 px-5 py-4 hover:bg-brand-50"
                >
                  <Avatar name={nutritionist.name} photoUrl={nutritionist.photo_url} className="h-10 w-10" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium text-brand-600">{nutritionist.name}</p>
                    <p className="text-xs text-slate-500">Nutritionist • {nutritionist.license_number}</p>
                  </div>
                  <span className="text-sm text-brand-600">View requests →</span>
                </Link>
              </li>
            ))}
          </ul>

          <Pagination page={page} totalPages={result.meta.total_pages} onPageChange={setPage} />
        </>
      )}
    </section>
  )
}

export default ProfessionalsPage
