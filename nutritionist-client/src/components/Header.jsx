import { Link } from 'react-router'

function Header() {
  return (
    <header className="bg-gradient-to-r from-brand-500 to-brand-600 text-white">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
        <Link to="/" className="flex items-center gap-2 text-xl font-semibold tracking-wide">
          <HeartIcon />
          Nutrium
        </Link>

        <Link to="/professionals" className="text-sm hover:underline">
          <span className="hidden sm:inline">Are you a nutrition professional? </span>
          See your requests →
        </Link>
      </div>
    </header>
  )
}

function HeartIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-6 w-6" fill="currentColor" aria-hidden="true">
      <path d="M12 21s-7.5-4.6-9.6-9.2C.9 8.4 3 4.5 6.7 4.5c2.1 0 3.6 1.1 4.3 2.4.7-1.3 2.2-2.4 4.3-2.4 3.7 0 5.8 3.9 4.3 7.3C19.5 16.4 12 21 12 21z" />
    </svg>
  )
}

export default Header
