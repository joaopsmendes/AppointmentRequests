import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router'
import { listAppointmentRequests } from '../api/appointmentRequests'
import AnswerRequestModal from '../components/AnswerRequestModal'
import AppointmentRequestCard from '../components/AppointmentRequestCard'

const PER_PAGE = 3

const TABS = {
  pending: { label: 'Pending', title: 'Pending Requests', subtitle: 'Accept or reject new pending requests', empty: 'There are no pending requests.' },
  accepted: { label: 'Accepted', title: 'Accepted Requests', subtitle: 'Appointments you have accepted', empty: 'No accepted requests yet.' },
  rejected: { label: 'Rejected', title: 'Rejected Requests', subtitle: 'Requests you have rejected', empty: 'No rejected requests yet.' },
}

function PendingRequestsPage() {
  const { nutritionistId } = useParams()
  const [status, setStatus] = useState('pending')
  const [page, setPage] = useState(1)

  const [result, setResult] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState(null)

  const [reloadCount, setReloadCount] = useState(0)
  const [answering, setAnswering] = useState(null)
  const [notice, setNotice] = useState(null)

  useEffect(() => {
    let ignore = false

    async function loadRequests() {
      setIsLoading(true)
      setError(null)
      try {
        const response = await listAppointmentRequests(nutritionistId, { status, page, perPage: PER_PAGE })
        if (ignore) return

        if (response.data.length === 0 && page > 1) {
          setPage(page - 1)
          return
        }
        setResult(response)
      } catch (requestError) {
        if (!ignore) setError(requestError)
      } finally {
        if (!ignore) setIsLoading(false)
      }
    }

    loadRequests()

    return () => {
      ignore = true
    }
  }, [nutritionistId, status, page, reloadCount])

  function reload() {
    setReloadCount((count) => count + 1)
  }

  function handleStatusChange(newStatus) {
    setStatus(newStatus)
    setPage(1) 
  }

  function handleAnswered({ appointment_request: answered, auto_rejected_ids: autoRejectedIds }) {
    const autoRejectedCount = autoRejectedIds.length
    let message = `Request from ${answered.guest.name} ${answered.status}. The guest will be notified by email.`
    if (autoRejectedCount > 0) {
      message += ` ${autoRejectedCount} overlapping request${autoRejectedCount > 1 ? 's were' : ' was'} automatically rejected.`
    }

    setAnswering(null)
    setNotice(message)
    reload()
  }

  const totalPages = result?.meta.total_pages ?? 0
  const tab = TABS[status]

  return (
    <section className="mx-auto max-w-5xl px-4 py-8">
      <Link to="/professionals" className="mb-4 inline-block text-sm text-brand-600 hover:underline">
        ← Choose another profile
      </Link>

      <div className="rounded border border-slate-200 bg-white p-5 shadow-sm">
        <div className="mb-6 flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 className="text-xl text-slate-800">
              {tab.title}
              {!isLoading && result && <span className="text-slate-500"> ({result.meta.total_count})</span>}
            </h1>
            <p className="text-sm text-slate-500">{tab.subtitle}</p>
          </div>

          <div className="flex items-center gap-3">
            <div role="tablist" aria-label="Request status" className="flex rounded border border-slate-200 bg-white p-0.5 text-sm">
              {Object.entries(TABS).map(([tabStatus, { label }]) => (
                <button
                  key={tabStatus}
                  type="button"
                  role="tab"
                  aria-selected={tabStatus === status}
                  onClick={() => handleStatusChange(tabStatus)}
                  className={`rounded px-3 py-1 ${
                    tabStatus === status ? 'bg-brand-50 font-medium text-brand-600' : 'text-slate-500 hover:text-slate-700'
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>

            {totalPages > 1 && (
              <div className="flex gap-1">
                <ArrowButton label="Previous page" onClick={() => setPage(page - 1)} disabled={page === 1}>
                  ‹
                </ArrowButton>
                <ArrowButton label="Next page" onClick={() => setPage(page + 1)} disabled={page === totalPages}>
                  ›
                </ArrowButton>
              </div>
            )}
          </div>
        </div>

        {notice && (
          <div role="status" className="mb-4 flex items-start justify-between gap-4 rounded bg-brand-50 p-4 text-sm text-brand-600">
            <p>{notice}</p>
            <button type="button" onClick={() => setNotice(null)} aria-label="Dismiss" className="leading-none">
              ×
            </button>
          </div>
        )}

        {error && (
          <p className="rounded bg-red-50 p-4 text-red-700">
            {error.status === 404 ? 'Nutritionist not found.' : 'Could not load the requests. Please try again.'}
          </p>
        )}

        {/* "Loading..." only on the first load; on reloads the current cards stay visible, faded. */}
        {!error && !result && isLoading && <p className="text-slate-500">Loading requests...</p>}

        {!error && result && (
          <div className={isLoading ? 'opacity-60 transition-opacity' : 'transition-opacity'}>
            {result.data.length === 0 ? (
              <p className="py-6 text-slate-500">{tab.empty}</p>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {result.data.map((appointmentRequest) => (
                  <AppointmentRequestCard
                    key={appointmentRequest.id}
                    appointmentRequest={appointmentRequest}
                    onAnswer={setAnswering}
                  />
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {answering && (
        <AnswerRequestModal
          appointmentRequest={answering}
          onClose={() => setAnswering(null)}
          onAnswered={handleAnswered}
          onOutdated={reload}
        />
      )}
    </section>
  )
}

function ArrowButton({ children, label, onClick, disabled }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      className="h-8 w-8 rounded border border-slate-200 bg-white text-slate-500 hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-40"
    >
      {children}
    </button>
  )
}

export default PendingRequestsPage
