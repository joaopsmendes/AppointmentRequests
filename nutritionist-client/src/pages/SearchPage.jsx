import { useEffect, useState } from 'react'
import { searchNutritionists } from '../api/nutritionists'
import NutritionistCard from '../components/NutritionistCard'
import { MapPinIcon } from '../components/icons'
import Pagination from '../components/Pagination'
import ScheduleAppointmentModal from '../components/ScheduleAppointmentModal'

const PER_PAGE = 3

function SearchPage() {
  const [inputValue, setInputValue] = useState('')
  const [query, setQuery] = useState('')
  const [locationInput, setLocationInput] = useState('')
  const [location, setLocation] = useState('')
  const [page, setPage] = useState(1)

  const [result, setResult] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState(null)

  const [scheduling, setScheduling] = useState(null)

  useEffect(() => {
    let ignore = false

    async function loadNutritionists() {
      setIsLoading(true)
      setError(null)
      try {
        const response = await searchNutritionists({ query, location, page, perPage: PER_PAGE })
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
  }, [query, location, page])

  function handleSubmit(event) {
    event.preventDefault()
    setQuery(inputValue.trim())
    setLocation(locationInput.trim())
    setPage(1)
  }

  function handlePageChange(newPage) {
    setPage(newPage)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  return (
    <>
      <section className="bg-gradient-to-r from-brand-500 to-brand-600">
        <form onSubmit={handleSubmit} className="mx-auto flex max-w-5xl flex-col gap-3 px-4 py-8 sm:flex-row">
          <input
            type="search"
            value={inputValue}
            onChange={(event) => setInputValue(event.target.value)}
            placeholder="Name or service, e.g. sports nutrition..."
            aria-label="Search by nutritionist name or service"
            className="min-w-0 flex-1 rounded bg-white px-4 py-3 text-sm shadow-sm outline-none focus:ring-2 focus:ring-accent-500"
          />
          <div className="relative min-w-0 flex-1">
            <input
              type="search"
              value={locationInput}
              onChange={(event) => setLocationInput(event.target.value)}
              placeholder="Location, e.g. Porto or Online"
              aria-label="Location"
              className="w-full rounded bg-white px-4 py-3 pr-10 text-sm shadow-sm outline-none focus:ring-2 focus:ring-accent-500"
            />
            <MapPinIcon className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-brand-500" />
          </div>
          <button
            type="submit"
            className="rounded bg-accent-500 px-6 py-3 text-sm font-medium text-white shadow-sm hover:bg-accent-600"
          >
            Search
          </button>
        </form>
      </section>

      <section className="mx-auto max-w-5xl px-4 py-8">
        {isLoading && <p className="text-slate-500">Loading nutritionists...</p>}

        {!isLoading && error && (
          <p className="rounded bg-red-50 p-4 text-red-700">
            Could not load the nutritionists. Please try again.
          </p>
        )}

        {!isLoading && !error && result && (
          <>
            <p className="mb-4 text-sm text-slate-500">
              {result.meta.total_count} nutritionist(s) found{query && ` for "${query}"`}
              {location && ` in "${location}"`}
            </p>
            {result.data.length === 0 ? (
              <p className="rounded bg-white p-6 text-slate-500 shadow-sm">
                No nutritionists match your search. Try another name, service or location.
              </p>
            ) : (
              <div className="flex flex-col gap-4">
                {result.data.map((nutritionist) => (
                  <NutritionistCard
                    key={`${nutritionist.id}-${query}-${location}`}
                    nutritionist={nutritionist}
                    query={query}
                    location={location}
                    onSchedule={(chosenNutritionist, service) => setScheduling({ nutritionist: chosenNutritionist, service })}
                  />
                ))}
              </div>
            )}

            <Pagination page={page} totalPages={result.meta.total_pages} onPageChange={handlePageChange} />
          </>
        )}
      </section>

      {scheduling && (
        <ScheduleAppointmentModal
          nutritionist={scheduling.nutritionist}
          initialService={scheduling.service}
          onClose={() => setScheduling(null)}
        />
      )}
    </>
  )
}

export default SearchPage
