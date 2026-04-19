import { application } from "./custom"
import ClipboardController from "./clipboard_controller"
import ThemeController from "./theme_controller"
import DropdownController from "./dropdown_controller"
import AssistantChatController from "./assistant_chat_controller"

application.register("clipboard", ClipboardController)
application.register("theme", ThemeController)
application.register("dropdown", DropdownController)
application.register("assistant-chat", AssistantChatController)

// AI Content Controller
import AiContentController from "./ai_content_controller"
application.register("ai-content", AiContentController)
application.register("assistant-chat", AssistantChatController)

// Editable Content Controller
import EditableContentController from "./editable_content_controller"
application.register("editable-content", EditableContentController)
application.register("assistant-chat", AssistantChatController)

// Workflow Controller
import WorkflowController from "./workflow_controller"
application.register("workflow", WorkflowController)
application.register("assistant-chat", AssistantChatController)

// Additional Controllers
import AiMarketingStrategyController from "./ai_marketing_strategy_controller"
application.register("ai-marketing-strategy", AiMarketingStrategyController)
application.register("assistant-chat", AssistantChatController)


import VoiceCommandController from "./voice_command_controller"
application.register("voice-command", VoiceCommandController)
application.register("assistant-chat", AssistantChatController)

import VoiceCommandToggleController from "./voice_command_toggle_controller"
application.register("voice-command-toggle", VoiceCommandToggleController)
application.register("assistant-chat", AssistantChatController)

import CalendarController from "./calendar_controller"
application.register("calendar", CalendarController)
application.register("assistant-chat", AssistantChatController)

import CampaignWorkflowController from "./campaign_workflow_controller"
application.register("campaign-workflow", CampaignWorkflowController)
application.register("assistant-chat", AssistantChatController)


import ContentCreationController from "./content_creation_controller"
application.register("content-creation", ContentCreationController)
application.register("assistant-chat", AssistantChatController)

import ContentIndexController from "./content_index_controller"
application.register("content-index", ContentIndexController)
application.register("assistant-chat", AssistantChatController)

import ContentNewController from "./content_new_controller"
application.register("content-new", ContentNewController)
application.register("assistant-chat", AssistantChatController)

import ContinuousVoiceController from "./continuous_voice_controller"
application.register("continuous-voice", ContinuousVoiceController)
application.register("assistant-chat", AssistantChatController)

import DashboardAutopilotController from "./dashboard_autopilot_controller"
application.register("dashboard-autopilot", DashboardAutopilotController)
application.register("assistant-chat", AssistantChatController)

import FlashController from "./flash_controller"
application.register("flash", FlashController)
application.register("assistant-chat", AssistantChatController)

import FlatpickrController from "./flatpickr_controller"
application.register("flatpickr", FlatpickrController)
application.register("assistant-chat", AssistantChatController)

import MobileWebviewController from "./mobile_webview_controller"
application.register("mobile-webview", MobileWebviewController)
application.register("assistant-chat", AssistantChatController)

import PolicySettingsController from "./policy_settings_controller"
application.register("policy-settings", PolicySettingsController)
application.register("assistant-chat", AssistantChatController)

import PwaInstallController from "./pwa_install_controller"
application.register("pwa-install", PwaInstallController)
application.register("assistant-chat", AssistantChatController)

import ResponseTestController from "./response_test_controller"
application.register("response-test", ResponseTestController)
application.register("assistant-chat", AssistantChatController)

import ScheduledPostNewController from "./scheduled_post_new_controller"
application.register("scheduled-post-new", ScheduledPostNewController)
application.register("assistant-chat", AssistantChatController)

import ScheduledPostsController from "./scheduled_posts_controller"
application.register("scheduled-posts", ScheduledPostsController)
application.register("assistant-chat", AssistantChatController)

import SdkIntegrationController from "./sdk_integration_controller"
application.register("sdk-integration", SdkIntegrationController)
application.register("assistant-chat", AssistantChatController)

import SimpleVoiceController from "./simple_voice_controller"
application.register("simple-voice", SimpleVoiceController)
application.register("assistant-chat", AssistantChatController)

import SocialAccountConnectionsController from "./social_account_connections_controller"
application.register("social-account-connections", SocialAccountConnectionsController)
application.register("assistant-chat", AssistantChatController)

import StrategyTrendController from "./strategy_trend_controller"
application.register("strategy-trend", StrategyTrendController)
application.register("assistant-chat", AssistantChatController)

import SystemMonitorController from "./system_monitor_controller"
application.register("system-monitor", SystemMonitorController)
application.register("assistant-chat", AssistantChatController)

import TomSelectController from "./tom_select_controller"
application.register("tom-select", TomSelectController)
application.register("assistant-chat", AssistantChatController)

import VideoProgressController from "./video_progress_controller"
application.register("video-progress", VideoProgressController)
application.register("assistant-chat", AssistantChatController)


import VoiceFloatController from "./voice_float_controller"
application.register("voice-float", VoiceFloatController)
application.register("assistant-chat", AssistantChatController)

import VoiceInteractionController from "./voice_interaction_controller"
application.register("voice-interaction", VoiceInteractionController)
application.register("assistant-chat", AssistantChatController)

import VoiceToggleController from "./voice_toggle_controller"
application.register("voice-toggle", VoiceToggleController)
application.register("assistant-chat", AssistantChatController)

// Campaign Builder Controller
import CampaignBuilderController from "./campaign_builder_controller"
application.register("campaign-builder", CampaignBuilderController)
application.register("assistant-chat", AssistantChatController)

import CampaignCustomizerController from "./campaign_customizer_controller"
application.register("campaign-customizer", CampaignCustomizerController)
application.register("assistant-chat", AssistantChatController)

// Accordion Controller
import AccordionController from "./accordion_controller"
application.register("accordion", AccordionController)
application.register("assistant-chat", AssistantChatController)

// Otto Controller
import OttoController from "./otto_controller"
application.register("otto", OttoController)
