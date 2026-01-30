import { useState } from 'react';
import { generateDraft } from '../services/api';
import { FileText, Loader2 } from 'lucide-react';

function DraftPage() {
  const [prompt, setPrompt] = useState('');
  const [draft, setDraft] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleGenerate = async () => {
    if (!prompt.trim()) {
      setError('Please enter a prompt');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const result = await generateDraft(prompt);
      setDraft(result.content || '');
    } catch (err) {
      setError('Failed to generate draft. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <h2 className="text-2xl font-bold mb-6">Generate Draft</h2>

      <div className="bg-white rounded-lg shadow p-6">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Enter your prompt
        </label>
        <textarea
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          rows="4"
          placeholder="Describe what you want to generate..."
        />

        {error && (
          <div className="mt-4 p-3 bg-red-100 text-red-700 rounded-lg">
            {error}
          </div>
        )}

        <button
          onClick={handleGenerate}
          disabled={loading}
          className="mt-4 w-full bg-blue-600 text-white py-3 px-4 rounded-lg hover:bg-blue-700 disabled:bg-blue-400 flex items-center justify-center gap-2"
        >
          {loading ? (
            <>
              <Loader2 className="animate-spin w-5 h-5" />
              Generating...
            </>
          ) : (
            <>
              <FileText className="w-5 h-5" />
              Generate Draft
            </>
          )}
        </button>

        {draft && (
          <div className="mt-6">
            <h3 className="text-lg font-semibold mb-2">Generated Draft</h3>
            <div className="p-4 bg-gray-50 rounded-lg whitespace-pre-wrap">
              {draft}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default DraftPage;
