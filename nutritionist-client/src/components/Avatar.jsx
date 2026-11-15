function Avatar({ name, photoUrl, className = 'h-16 w-16' }) {
  if (photoUrl) {
    return <img src={photoUrl} alt="" className={`${className} shrink-0 rounded-full bg-brand-50`} />
  }

  const initials = name
    .split(' ')
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()

  return (
    <div className={`${className} flex shrink-0 items-center justify-center rounded-full bg-brand-50 font-medium text-brand-600`}>
      {initials}
    </div>
  )
}

export default Avatar
