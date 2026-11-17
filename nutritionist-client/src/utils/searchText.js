export function normalizeSearchText(text) {
  return text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim()
}

function contains(text, term) {
  return normalizeSearchText(text).includes(normalizeSearchText(term))
}

export function findInitialService(services, { query = '', location = '' } = {}) {
  const matchesQuery = (service) => query === '' || contains(service.description, query)
  const matchesLocation = (service) => location === '' || contains(service.location, location)

  return (
    services.find((service) => matchesQuery(service) && matchesLocation(service)) ??
    services.find(matchesLocation) ??
    services[0]
  )
}
