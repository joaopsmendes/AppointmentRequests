import { request } from './client'

// GET /api/nutritionists?q=&location=&page=&per_page=
export function searchNutritionists({ query = '', location = '', page = 1, perPage } = {}) {
  const params = new URLSearchParams({ q: query, location, page })
  if (perPage) params.set('per_page', perPage)
  return request(`/api/nutritionists?${params}`)
}
