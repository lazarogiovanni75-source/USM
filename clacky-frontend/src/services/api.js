import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3001';

const api = axios.create({
  baseURL: API_BASE,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Draft functions
export const generateDraft = async (prompt) => {
  try {
    const response = await api.post('/api/ai/generate-content', { prompt });
    return response.data;
  } catch (error) {
    console.error('Error generating draft:', error);
    throw error;
  }
};

export const getPendingDrafts = async () => {
  try {
    const response = await api.get('/approval');
    return response.data;
  } catch (error) {
    console.error('Error fetching pending drafts:', error);
    throw error;
  }
};

export const getApprovedDrafts = async () => {
  try {
    const response = await api.get('/approval/approved');
    return response.data;
  } catch (error) {
    console.error('Error fetching approved drafts:', error);
    throw error;
  }
};

export const getRejectedDrafts = async () => {
  try {
    const response = await api.get('/approval/rejected');
    return response.data;
  } catch (error) {
    console.error('Error fetching rejected drafts:', error);
    throw error;
  }
};

export const approveDraft = async (draftId) => {
  try {
    const response = await api.post(`/approval/approve/${draftId}`);
    return response.data;
  } catch (error) {
    console.error('Error approving draft:', error);
    throw error;
  }
};

export const rejectDraft = async (draftId) => {
  try {
    const response = await api.post(`/approval/reject/${draftId}`);
    return response.data;
  } catch (error) {
    console.error('Error rejecting draft:', error);
    throw error;
  }
};

// Video functions
export const startVideo = async (prompt) => {
  try {
    const response = await api.post('/video/start', { prompt });
    return response.data;
  } catch (error) {
    console.error('Error starting video:', error);
    throw error;
  }
};

export const getVideoStatus = async (jobId) => {
  try {
    const response = await api.get(`/video/status/${jobId}`);
    return response.data;
  } catch (error) {
    console.error('Error fetching video status:', error);
    throw error;
  }
};

// Chat functions
export const sendChat = async (message, userId = 'default-user') => {
  try {
    const response = await api.post('/api/chat', { message, userId });
    return response.data;
  } catch (error) {
    console.error('Error sending chat message:', error);
    throw error;
  }
};

export default api;
