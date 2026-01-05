import { useQuery } from '@tanstack/react-query'

function App() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['health'],
    queryFn: async () => {
      const res = await fetch('/api/health')
      return res.json()
    },
  })

  return (
    <div className="app">
      <header className="header">
        <h1>Keenetic Dashboard</h1>
      </header>
      <main className="main">
        <div className="card">
          <h2>API Status</h2>
          {isLoading && <p className="status-loading">Connecting...</p>}
          {error && <p className="status-error">Connection failed</p>}
          {data && (
            <p className="status-ok">
              Connected • {data.timestamp}
            </p>
          )}
        </div>
      </main>
    </div>
  )
}

export default App

