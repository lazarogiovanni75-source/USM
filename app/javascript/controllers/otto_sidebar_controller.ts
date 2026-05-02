import { Controller } from "@hotwired/stimulus";

export default class OttoSidebarController extends Controller {
  static targets = ["list"];

  private csrfToken: string | null = null;
  private currentConversationId: string | null = null;

  connect() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    this.csrfToken = meta instanceof HTMLMetaElement ? meta.content : null;

    // Listen for open-sidebar event from Otto controller
    document.addEventListener('otto:open-sidebar', this.open.bind(this));
  }

  disconnect() {
    document.removeEventListener('otto:open-sidebar', this.open.bind(this));
  }

  open() {
    const sidebar = document.getElementById('otto-sidebar');
    if (sidebar) {
      sidebar.classList.add('open');
      this.loadConversations();
    }
  }

  close() {
    const sidebar = document.getElementById('otto-sidebar');
    if (sidebar) {
      sidebar.classList.remove('open');
    }
  }

  async loadConversations() {
    try {
      // Try API endpoint first, then fall back to Rails endpoint
      let response = await fetch('/api/v1/otto/conversations', {
        headers: {
          'X-CSRF-Token': this.csrfToken || '',
          'Accept': 'application/json'
        }
      });

      if (!response.ok) {
        // Fall back to Rails assistants endpoint
        response = await fetch('/assistants/', {
          headers: {
            'X-CSRF-Token': this.csrfToken || '',
            'Accept': 'application/json'
          }
        });
      }

      if (!response.ok) throw new Error('Failed to load conversations');

      const data = await response.json();
      this.renderConversations(data.conversations || []);
    } catch (error) {
      console.error('[OttoSidebar] Error loading conversations:', error);
    }
  }

  private renderConversations(conversations: Array<{
    id: number;
    title: string;
    updated_at: string;
    message_count: number;
  }>) {
    const container = document.getElementById('otto-conversations-container');
    if (!container) return;

    if (conversations.length === 0) {
      container.innerHTML = `
        <div class="text-center py-8 text-gray-400">
          <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="none"
               viewBox="0 0 24 24" stroke="currentColor" class="mx-auto mb-2 opacity-50">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"
                  d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8
                  a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12
                  c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
          </svg>
          <p class="text-sm">No conversations yet</p>
          <p class="text-xs mt-1">Start chatting to see them here</p>
        </div>
      `;
      return;
    }

    container.innerHTML = conversations.map(conv => `
      <div class="otto-conversation-item
                  ${conv.id.toString() === this.currentConversationId ? 'active' : ''}"
           data-action="click->otto-sidebar#selectConversation"
           data-conversation-id="${conv.id}">
        <div class="flex-1 min-w-0">
          <div class="text-sm font-medium text-gray-800 dark:text-gray-200 truncate">
            ${this.escapeHtml(conv.title)}
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
            ${this.formatDate(conv.updated_at)} · ${conv.message_count} messages
          </div>
        </div>
        <button class="otto-conversation-delete text-gray-400 hover:text-red-500"
                data-action="click->otto-sidebar#deleteConversation"
                data-conversation-id="${conv.id}"
                title="Delete conversation">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"
               fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858
                  L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
          </svg>
        </button>
      </div>
    `).join('');
  }

  async selectConversation(event: Event) {
    const target = event.target as HTMLElement;
    // Don't trigger if clicking delete button
    if (target.closest('.otto-conversation-delete')) return;

    const item = event.currentTarget as HTMLElement;
    const conversationId = item.dataset.conversationId;
    if (!conversationId) return;

    try {
      // Try API endpoint first, then fall back to Rails endpoint
      let response = await fetch(`/api/v1/otto/history?conversation_id=${conversationId}`, {
        headers: {
          'X-CSRF-Token': this.csrfToken || '',
          'Accept': 'application/json'
        }
      });

      if (!response.ok) {
        // Fall back to Rails assistants endpoint
        response = await fetch(`/assistants/${conversationId}`, {
          headers: {
            'X-CSRF-Token': this.csrfToken || '',
            'Accept': 'application/json'
          }
        });
      }

      if (!response.ok) throw new Error('Failed to load conversation');

      const data = await response.json();
      this.currentConversationId = conversationId;

      // Update UI - highlight selected
      this.updateActiveState(conversationId);

      // Notify Otto controller to load this conversation
      const loadEvent = new CustomEvent('otto:load-conversation', {
        detail: {
          id: data.conversation_id || conversationId,
          title: data.title || 'Conversation',
          messages: data.messages || []
        }
      });
      document.dispatchEvent(loadEvent);

      // Close sidebar on mobile
      if (window.innerWidth < 768) {
        this.close();
      }
    } catch (error) {
      console.error('[OttoSidebar] Error selecting conversation:', error);
    }
  }

  async deleteConversation(event: Event) {
    event.stopPropagation();
    const button = event.currentTarget as HTMLElement;
    const conversationId = button.dataset.conversationId;
    if (!conversationId) return;

    // Simple confirmation using window.confirm (eslint disable for this line)
    // eslint-disable-next-line no-alert
    if (!window.confirm('Delete this conversation? This cannot be undone.')) {
      return;
    }

    try {
      const response = await fetch(`/assistants/${conversationId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.csrfToken || '',
          'Accept': 'application/json'
        }
      });

      if (!response.ok) throw new Error('Failed to delete conversation');

      // If this was the current conversation, notify Otto
      if (this.currentConversationId === conversationId) {
        this.currentConversationId = null;
        const deleteEvent = new CustomEvent('otto:conversation-deleted', {
          detail: { id: conversationId }
        });
        document.dispatchEvent(deleteEvent);
      }

      // Refresh list
      this.loadConversations();
    } catch (error) {
      console.error('[OttoSidebar] Error deleting conversation:', error);
    }
  }

  newChat() {
    this.currentConversationId = null;

    // Notify Otto to start fresh
    const newEvent = new CustomEvent('otto:new-conversation');
    document.dispatchEvent(newEvent);

    // Close sidebar on mobile
    if (window.innerWidth < 768) {
      this.close();
    }

    // Refresh list to show new empty conversation at top
    this.loadConversations();
  }

  setCurrentConversation(id: string | null) {
    this.currentConversationId = id;
    this.updateActiveState(id);
  }

  private updateActiveState(conversationId: string | null) {
    document.querySelectorAll('.otto-conversation-item').forEach(item => {
      const itemId = (item as HTMLElement).dataset.conversationId;
      item.classList.toggle('active', itemId === conversationId);
    });
  }

  private escapeHtml(text: string): string {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  private formatDate(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;

    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }
}
