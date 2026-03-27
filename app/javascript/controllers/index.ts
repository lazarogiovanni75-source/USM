import { application } from "./custom"
import ClipboardController from "./clipboard_controller"
import ThemeController from "./theme_controller"
import DropdownController from "./dropdown_controller"

application.register("clipboard", ClipboardController)
application.register("theme", ThemeController)
application.register("dropdown", DropdownController)

// AI Content Controller
import AiContentController from "./ai_content_controller"
application.register("ai-content", AiContentController)

// Editable Content Controller
import EditableContentController from "./editable_content_controller"
application.register("editable-content", EditableContentController)

// Workflow Controller
import WorkflowController from "./workflow_controller"
application.register("workflow", WorkflowController)

// Additional Controllers
import AiChatController from "./ai_chat_controller"
application.register("ai-chat", AiChatController)

import AiMarketingStrategyController from "./ai_marketing_strategy_controller"
application.register("ai-marketing-strategy", AiMarketingStrategyController)

import AiVoiceChatController from "./ai_voice_chat_controller"
application.register("ai-voice-chat", AiVoiceChatController)

import AssemblyAiVoiceController from "./assembly_ai_voice_controller"
application.register("assembly-ai-voice", AssemblyAiVoiceController)

import CalendarController from "./calendar_controller"
application.register("calendar", CalendarController)

import CampaignWorkflowController from "./campaign_workflow_controller"
application.register("campaign-workflow", CampaignWorkflowController)

import ContentCreationController from "./content_creation_controller"
application.register("content-creation", ContentCreationController)

import ContentIndexController from "./content_index_controller"
application.register("content-index", ContentIndexController)

import ContentNewController from "./content_new_controller"
application.register("content-new", ContentNewController)

import ContinuousVoiceController from "./continuous_voice_controller"
application.register("continuous-voice", ContinuousVoiceController)

import DashboardAutopilotController from "./dashboard_autopilot_controller"
application.register("dashboard-autopilot", DashboardAutopilotController)

import FlashController from "./flash_controller"
application.register("flash", FlashController)

import FlatpickrController from "./flatpickr_controller"
application.register("flatpickr", FlatpickrController)

import MobileWebviewController from "./mobile_webview_controller"
application.register("mobile-webview", MobileWebviewController)

import PolicySettingsController from "./policy_settings_controller"
application.register("policy-settings", PolicySettingsController)

import PwaInstallController from "./pwa_install_controller"
application.register("pwa-install", PwaInstallController)

import ResponseTestController from "./response_test_controller"
application.register("response-test", ResponseTestController)

import ScheduledPostNewController from "./scheduled_post_new_controller"
application.register("scheduled-post-new", ScheduledPostNewController)

import ScheduledPostsController from "./scheduled_posts_controller"
application.register("scheduled-posts", ScheduledPostsController)

import SdkIntegrationController from "./sdk_integration_controller"
application.register("sdk-integration", SdkIntegrationController)

import SimpleVoiceController from "./simple_voice_controller"
application.register("simple-voice", SimpleVoiceController)

import SocialAccountConnectionsController from "./social_account_connections_controller"
application.register("social-account-connections", SocialAccountConnectionsController)

import StrategyTrendController from "./strategy_trend_controller"
application.register("strategy-trend", StrategyTrendController)

import SystemMonitorController from "./system_monitor_controller"
application.register("system-monitor", SystemMonitorController)

import TomSelectController from "./tom_select_controller"
application.register("tom-select", TomSelectController)

import VideoProgressController from "./video_progress_controller"
application.register("video-progress", VideoProgressController)

import VoiceChatController from "./voice_chat_controller"
application.register("voice-chat", VoiceChatController)

import VoiceCommandController from "./voice_command_controller"
application.register("voice-command", VoiceCommandController)

import VoiceCommandToggleController from "./voice_command_toggle_controller"
application.register("voice-command-toggle", VoiceCommandToggleController)

import VoiceFloatController from "./voice_float_controller"
application.register("voice-float", VoiceFloatController)

import VoiceInteractionController from "./voice_interaction_controller"
application.register("voice-interaction", VoiceInteractionController)

import VoiceToggleController from "./voice_toggle_controller"
application.register("voice-toggle", VoiceToggleController)

// Campaign Builder Controller
import CampaignBuilderController from "./campaign_builder_controller"
application.register("campaign-builder", CampaignBuilderController)

import CampaignCustomizerController from "./campaign_customizer_controller"
application.register("campaign-customizer", CampaignCustomizerController)
