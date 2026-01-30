import { useState } from 'react';
import { sendChat } from '../services/api';
import { Send, Loader2, Bot } from 'lucide-react';

function ChatPage() {
  const [message, setMessage] = useState('');
  const [userId, setUserId] = useState('default-user');
  const [responses, setResponses] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSend = async (e) => {
    e.preventDefault();
    if (!message.trim()) return;

    const userMessage = { text: message, sender: 'user', timestamp: new Date() };
    setResponses((prev) => [...prev, userMessage]);
    setMessage('');
    setLoading(true);
    setError('');

    try {
      const result = await sendChat(message, userId);
      const botMessage = {
        text: result.response || 'No response',
        sender: 'bot',
        timestamp: new Date(),
      };
      setResponses((prev) => [...prev, botMessage]);
    } catch (err) {
      setError('Failed to send message. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <h2 className="text-2xl font-bold mb-6">AI Chat</h2>

      <div className="bg-white rounded-lg shadow p-6">
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            User ID
          </label>
          <input
            type="text"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>

        <div className="bg-gray-50 rounded-lg p-4 mb-4 h-80 overflow-y-auto">
          {responses.length === 0 ? (
            <p className="text-gray-500 text-center py-8">
              Start a conversation with the AI...
            </p>
          ) : (
            <div className="space-y-4">
              {responses.map((msg, index) => (
                <div
                  key={index}
                  className={`flex ${msg.sender === 'user' ? 'justify-end' : 'justify-start'}`}
                >
                  <div
                    className={`max-w-3/4 rounded-lg p-3 ${
                      msg.sender === 'user'
                        ? 'bg-blue-600 text-white'
                        : 'bg-gray-200 text-gray-800'
                    }`}
                  >
                    {msg.sender === 'bot' && (
                      <Bot className="w-4 h-4 inline mr-2" />
                    )}
                    {msg.text}
                  </div>
                </div>
              ))}
              {loading && (
                <div className="flex justify-start">
                  <div className="bg-gray-200 text-gray-800 rounded-lg p-3 flex items-center gap-2">
                    <Loader2 className="w-4 h-4 animate-spin" />
                    Thinking...
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-100 text-red-700 rounded-lg">
            {error}
          </div>
        )}

        <form onSubmit={handleSend} className="flex gap-2">
          <input
            type="text"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="Type your message..."
            className="flex-1 p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            disabled={loading}
          />
          <button
            type="submit"
            disabled={loading || !message.trim()}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 disabled:bg-blue-400 flex items-center"
          >
            <Send className="w-5 h-5" />
          </button>
        </form>
      </div>
    </div>
  );
}

export default ChatPage;
