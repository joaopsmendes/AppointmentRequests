import { Route, Routes } from 'react-router'
import Header from './components/Header'
import NotFoundPage from './pages/NotFoundPage'
import PendingRequestsPage from './pages/PendingRequestsPage'
import SearchPage from './pages/SearchPage'

function App() {
  return (
    <>
      <Header />
      <main>
        <Routes>
          <Route path="/" element={<SearchPage />} />
          <Route path="/nutritionists/:nutritionistId/requests" element={<PendingRequestsPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </main>
    </>
  )
}

export default App
