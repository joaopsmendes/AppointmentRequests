import { Link } from 'react-router'

function Header() {
  return (
    <header className="bg-gradient-to-r from-brand-500 to-brand-600 text-white">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
        <Link to="/">
          <img src="/nutrium.png" alt="Nutrium" className="h-7 w-auto" />
        </Link>

        <Link to="/professionals" className="text-sm hover:underline">
          <span className="hidden sm:inline">Are you a nutrition professional? </span>
          See your requests →
        </Link>
      </div>
    </header>
  )
}

export default Header
