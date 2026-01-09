import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Layout } from './components/layout';
import { Dashboard, DeviceDetail, DeviceLogs, Devices, Interfaces, Policies, Routes as RoutesPage, System, SystemLogs } from './pages';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<Dashboard />} />
          <Route path="/devices" element={<Devices />} />
          <Route path="/devices/:mac" element={<DeviceDetail />} />
          <Route path="/logs" element={<DeviceLogs />} />
          <Route path="/system-logs" element={<SystemLogs />} />
          <Route path="/interfaces" element={<Interfaces />} />
          <Route path="/policies" element={<Policies />} />
          <Route path="/routes" element={<RoutesPage />} />
          <Route path="/system" element={<System />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
