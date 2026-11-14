const euroFormatter = new Intl.NumberFormat('en-IE', { style: 'currency', currency: 'EUR' })

// convert cents to euros and format as a currency string.
export function formatPrice(priceCents) {
  return euroFormatter.format(priceCents / 100)
}
