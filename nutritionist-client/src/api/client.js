export class ApiError extends Error {
  constructor(status, errors) {
    super(errors.length > 0 ? errors.join(' ') : `Request failed with status ${status}`)
    this.status = status
    this.errors = errors
  }
}

export async function request(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...options.headers,
    },
  })

  // Some error responses are not JSON (e.g. a proxy error page), so parsing may fail.
  const body = await response.json().catch(() => null)

  if (!response.ok) {
    throw new ApiError(response.status, body?.errors ?? [])
  }

  return body
}
