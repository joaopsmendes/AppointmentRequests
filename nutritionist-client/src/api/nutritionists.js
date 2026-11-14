import { request } from './client'

// GET /api/nutritionists?q=&page=&per_page=
export function searchNutritionists({ query = '', page = 1, perPage } = {}) {
  const params = new URLSearchParams({ q: query, page })
  if (perPage) params.set('per_page', perPage)
  return request(`/api/nutritionists?${params}`)
}
