import { request } from './client'

// GET /api/nutritionists?q=&page=...
export function searchNutritionists({ query = '', page = 1 } = {}) {
  const params = new URLSearchParams({ q: query, page })
  return request(`/api/nutritionists?${params}`)
}
