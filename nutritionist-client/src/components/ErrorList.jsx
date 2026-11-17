function ErrorList({ messages, className = '' }) {
  if (messages.length === 0) return null

  return (
    <ul role="alert" className={`rounded bg-red-50 p-3 text-sm text-red-700 ${className}`}>
      {messages.map((message) => (
        <li key={message}>{message}</li>
      ))}
    </ul>
  )
}

export default ErrorList
