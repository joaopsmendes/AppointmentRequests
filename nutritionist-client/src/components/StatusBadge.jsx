const BADGE_STYLES = {
  accepted: 'bg-brand-50 text-brand-600',
  rejected: 'bg-red-50 text-red-600',
}

function StatusBadge({ status }) {
  return <span className={`rounded px-2 py-0.5 text-xs font-medium capitalize ${BADGE_STYLES[status]}`}>{status}</span>
}

export default StatusBadge
