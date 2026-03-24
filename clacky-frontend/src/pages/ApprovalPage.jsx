import { useState, useEffect } from 'react';
import { getPendingDrafts, getApprovedDrafts, getRejectedDrafts, approveDraft, rejectDraft } from '../services/api';
import { Check, X, Clock, Loader2 } from 'lucide-react';

function ApprovalPage() {
  const [pendingDrafts, setPendingDrafts] = useState([]);
  const [approvedDrafts, setApprovedDrafts] = useState([]);
  const [rejectedDrafts, setRejectedDrafts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('pending');
  const [processingId, setProcessingId] = useState(null);

  const loadDrafts = async () => {
    setLoading(true);
    try {
      const [pending, approved, rejected] = await Promise.all([
        getPendingDrafts(),
        getApprovedDrafts(),
        getRejectedDrafts(),
      ]);
      setPendingDrafts(pending.drafts || []);
      setApprovedDrafts(approved.drafts || []);
      setRejectedDrafts(rejected.drafts || []);
    } catch (err) {
      console.error('Error loading drafts:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDrafts();
  }, []);

  const handleApprove = async (draftId) => {
    setProcessingId(draftId);
    try {
      await approveDraft(draftId);
      await loadDrafts();
    } catch (err) {
      console.error('Error approving draft:', err);
    } finally {
      setProcessingId(null);
    }
  };

  const handleReject = async (draftId) => {
    setProcessingId(draftId);
    try {
      await rejectDraft(draftId);
      await loadDrafts();
    } catch (err) {
      console.error('Error rejecting draft:', err);
    } finally {
      setProcessingId(null);
    }
  };

  const renderDraftList = (drafts, showActions = false) => {
    if (drafts.length === 0) {
      return (
        <p className="text-gray-500 text-center py-8">
          No drafts found
        </p>
      );
    }

    return (
      <div className="space-y-4">
        {drafts.map((draft) => (
          <div key={draft.id} className="bg-white rounded-lg shadow p-4">
            <p className="text-gray-800 whitespace-pre-wrap">{draft.text}</p>
            <p className="text-sm text-gray-500 mt-2">
              Created: {new Date(draft.created_at).toLocaleString()}
            </p>
            {showActions && (
              <div className="flex gap-2 mt-4">
                <button
                  onClick={() => handleApprove(draft.id)}
                  disabled={processingId === draft.id}
                  className="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 disabled:bg-green-400 flex items-center gap-2"
                >
                  {processingId === draft.id ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <Check className="w-4 h-4" />
                  )}
                  Approve
                </button>
                <button
                  onClick={() => handleReject(draft.id)}
                  disabled={processingId === draft.id}
                  className="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 disabled:bg-red-400 flex items-center gap-2"
                >
                  {processingId === draft.id ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <X className="w-4 h-4" />
                  )}
                  Reject
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    );
  };

  return (
    <div className="max-w-4xl mx-auto">
      <h2 className="text-2xl font-bold mb-6">Draft Approval</h2>

      <div className="bg-white rounded-lg shadow">
        <div className="flex border-b">
          <button
            onClick={() => setActiveTab('pending')}
            className={`flex-1 py-3 px-4 flex items-center justify-center gap-2 ${
              activeTab === 'pending'
                ? 'border-b-2 border-blue-600 text-blue-600'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <Clock className="w-4 h-4" />
            Pending ({pendingDrafts.length})
          </button>
          <button
            onClick={() => setActiveTab('approved')}
            className={`flex-1 py-3 px-4 flex items-center justify-center gap-2 ${
              activeTab === 'approved'
                ? 'border-b-2 border-blue-600 text-blue-600'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <Check className="w-4 h-4" />
            Approved ({approvedDrafts.length})
          </button>
          <button
            onClick={() => setActiveTab('rejected')}
            className={`flex-1 py-3 px-4 flex items-center justify-center gap-2 ${
              activeTab === 'rejected'
                ? 'border-b-2 border-blue-600 text-blue-600'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <X className="w-4 h-4" />
            Rejected ({rejectedDrafts.length})
          </button>
        </div>

        <div className="p-4">
          {loading ? (
            <div className="flex justify-center py-8">
              <Loader2 className="w-8 h-8 animate-spin text-blue-600" />
            </div>
          ) : (
            <>
              {activeTab === 'pending' && renderDraftList(pendingDrafts, true)}
              {activeTab === 'approved' && renderDraftList(approvedDrafts, false)}
              {activeTab === 'rejected' && renderDraftList(rejectedDrafts, false)}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export default ApprovalPage;
