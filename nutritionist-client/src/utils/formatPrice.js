const amountFormatter = new Intl.NumberFormat('en-IE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

// Converts cents to euros
export function formatPrice(priceCents) {
  return `€ ${amountFormatter.format(priceCents / 100)}`
}
