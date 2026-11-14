function Pagination({ page, totalPages, onPageChange }) {
  if (totalPages <= 1) return null

  const pages = Array.from({ length: totalPages }, (_, index) => index + 1)

  return (
    <nav aria-label="Pagination" className="mt-6 flex items-center gap-1 text-sm">
      <PageButton onClick={() => onPageChange(page - 1)} disabled={page === 1} label="Previous page">
        ‹
      </PageButton>

      {pages.map((pageNumber) => (
        <PageButton
          key={pageNumber}
          onClick={() => onPageChange(pageNumber)}
          isCurrent={pageNumber === page}
          label={`Page ${pageNumber}`}
        >
          {pageNumber}
        </PageButton>
      ))}

      <PageButton onClick={() => onPageChange(page + 1)} disabled={page === totalPages} label="Next page">
        ›
      </PageButton>
    </nav>
  )
}

function PageButton({ children, onClick, disabled = false, isCurrent = false, label }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      aria-current={isCurrent ? 'page' : undefined}
      className={`h-8 min-w-8 rounded px-2 ${
        isCurrent ? 'bg-brand-50 font-medium text-brand-600' : 'bg-white text-slate-500 hover:bg-slate-100'
      } disabled:cursor-not-allowed disabled:opacity-40`}
    >
      {children}
    </button>
  )
}

export default Pagination
