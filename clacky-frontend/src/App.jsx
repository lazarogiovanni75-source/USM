import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import DraftPage from './pages/DraftPage';
import ApprovalPage from './pages/ApprovalPage';
import VideoPage from './pages/VideoPage';
import ChatPage from './pages/ChatPage';

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-gray-100">
        <nav className="bg-blue-600 text-white p-4">
          <div className="container mx-auto">
            <h1 className="text-2xl font-bold mb-8">Ultimate Social Media</h1>
            <div className="flex gap-6">
              <Link to="/" className="hover:underline">Draft</Link>
              <Link to="/approval" className="hover:underline">Approval</Link>
              <Link to="/video" className="hover:underline">Video</Link>
              <Link to="/chat" className="hover:underline">Chat</Link>
            </div>
          </div>
        </nav>
        <main className="container mx-auto p-4">
          <Routes>
            <Route path="/" element={<DraftPage />} />
            <Route path="/approval" element={<ApprovalPage />} />
            <Route path="/video" element={<VideoPage />} />
            <Route path="/chat" element={<ChatPage />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
