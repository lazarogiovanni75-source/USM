import { useState } from 'react';
import { startVideo, getVideoStatus } from '../services/api';
import { Video, Loader2, Play } from 'lucide-react';

function VideoPage() {
  const [prompt, setPrompt] = useState('');
  const [jobId, setJobId] = useState('');
  const [videoStatus, setVideoStatus] = useState(null);
  const [loading, setLoading] = useState(false);
  const [polling, setPolling] = useState(false);
  const [error, setError] = useState('');

  const handleStartVideo = async () => {
    if (!prompt.trim()) {
      setError('Please enter a prompt for the video');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const result = await startVideo(prompt);
      setJobId(result.jobId);
      setVideoStatus({ status: 'pending' });
      setPolling(true);
    } catch (err) {
      setError('Failed to start video generation');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleCheckStatus = async () => {
    if (!jobId) return;

    setPolling(true);
    try {
      const result = await getVideoStatus(jobId);
      setVideoStatus(result);

      if (result.status === 'completed') {
        setPolling(false);
      }
    } catch (err) {
      console.error('Error checking status:', err);
    } finally {
      setPolling(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'completed':
        return 'bg-green-100 text-green-800';
      case 'failed':
        return 'bg-red-100 text-red-800';
      case 'processing':
        return 'bg-blue-100 text-blue-800';
      default:
        return 'bg-yellow-100 text-yellow-800';
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <h2 className="text-2xl font-bold mb-6">Generate Video</h2>

      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Video Prompt
        </label>
        <textarea
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          rows="3"
          placeholder="Describe the video you want to generate..."
        />

        {error && (
          <div className="mt-4 p-3 bg-red-100 text-red-700 rounded-lg">
            {error}
          </div>
        )}

        <button
          onClick={handleStartVideo}
          disabled={loading}
          className="mt-4 w-full bg-purple-600 text-white py-3 px-4 rounded-lg hover:bg-purple-700 disabled:bg-purple-400 flex items-center justify-center gap-2"
        >
          {loading ? (
            <>
              <Loader2 className="animate-spin w-5 h-5" />
              Starting...
            </>
          ) : (
            <>
              <Video className="w-5 h-5" />
              Start Video Generation
            </>
          )}
        </button>
      </div>

      {jobId && (
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold">Job: {jobId}</h3>
            <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(videoStatus?.status)}`}>
              {videoStatus?.status || 'unknown'}
            </span>
          </div>

          <button
            onClick={handleCheckStatus}
            disabled={polling}
            className="w-full bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 disabled:bg-blue-400 flex items-center justify-center gap-2"
          >
            {polling ? (
              <>
                <Loader2 className="animate-spin w-4 h-4" />
                Checking...
              </>
            ) : (
              <>
                <Play className="w-4 h-4" />
                Check Status
              </>
            )}
          </button>

          {videoStatus?.videoUrl && (
            <div className="mt-4">
              <h4 className="font-medium mb-2">Generated Video:</h4>
              <video
                controls
                className="w-full rounded-lg"
                src={videoStatus.videoUrl}
              >
                Your browser does not support video playback.
              </video>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default VideoPage;
