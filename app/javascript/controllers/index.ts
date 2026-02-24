import { Application } from "@hotwired/stimulus"

import ThemeController from "./theme_controller"
import DropdownController from "./dropdown_controller"
import SdkIntegrationController from "./sdk_integration_controller"
import ClipboardController from "./clipboard_controller"
import TomSelectController from "./tom_select_controller"
import FlatpickrController from "./flatpickr_controller"
import SystemMonitorController from "./system_monitor_controller"
import FlashController from "./flash_controller"
import VoiceInteractionController from "./voice_interaction_controller"
import VoiceCommandController from "./voice_command_controller"
import ContentIndexController from "./content_index_controller"
import ContentNewController from "./content_new_controller"
import ContentCreationController from "./content_creation_controller"
import ScheduledPostNewController from "./scheduled_post_new_controller"
import CalendarController from "./calendar_controller"
import PwaInstallController from "./pwa_install_controller"
import MobileWebviewController from "./mobile_webview_controller"
import ScheduledPostsController from "./scheduled_posts_controller"
import VoiceFloatController from "./voice_float_controller"
import SimpleVoiceController from "./simple_voice_controller"
import VoiceCommandToggleController from "./voice_command_toggle_controller"
import VideoProgressController from "./video_progress_controller"
import AiChatController from "./ai_chat_controller"
import AiVoiceChatController from "./ai_voice_chat_controller"
import VoiceToggleController from "./voice_toggle_controller"
import ResponseTestController from "./response_test_controller"
import AiMarketingStrategyController from "./ai_marketing_strategy_controller"
import DashboardAutopilotController from "./dashboard_autopilot_controller"
import SocialAccountConnectionsController from "./social_account_connections_controller"
import CampaignWorkflowController from "./campaign_workflow_controller"
import ContinuousVoiceController from "./continuous_voice_controller"
import VoiceChatController from "./voice_chat_controller"
import PolicySettingsController from "./policy_settings_controller"
import StrategyTrendController from "./strategy_trend_controller"

const application = Application.start()

application.register("theme", ThemeController)
application.register("dropdown", DropdownController)
application.register("sdk-integration", SdkIntegrationController)
application.register("clipboard", ClipboardController)
application.register("tom-select", TomSelectController)
application.register("flatpickr", FlatpickrController)
application.register("system-monitor", SystemMonitorController)
application.register("flash", FlashController)
application.register("voice-interaction", VoiceInteractionController)
application.register("voice-command", VoiceCommandController)
application.register("content-index", ContentIndexController)
application.register("content-new", ContentNewController)
application.register("content-creation", ContentCreationController)
application.register("scheduled-post-new", ScheduledPostNewController)
application.register("calendar", CalendarController)
application.register("pwa-install", PwaInstallController)
application.register("mobile-webview", MobileWebviewController)
application.register("scheduled-posts", ScheduledPostsController)
application.register("voice-float", VoiceFloatController)
application.register("simple-voice", SimpleVoiceController)
application.register("voice-command-toggle", VoiceCommandToggleController)
application.register("video-progress", VideoProgressController)
application.register("ai-chat", AiChatController)
application.register("ai-voice-chat", AiVoiceChatController)
application.register("voice-toggle", VoiceToggleController)
application.register("response-test", ResponseTestController)
application.register("ai-marketing-strategy", AiMarketingStrategyController)
application.register("dashboard-autopilot", DashboardAutopilotController)
application.register("social-account-connections", SocialAccountConnectionsController)
application.register("campaign-workflow", CampaignWorkflowController)
application.register("continuous-voice", ContinuousVoiceController)
application.register("voice-chat", VoiceChatController)
application.register("policy-settings", PolicySettingsController)
application.register("strategy-trend", StrategyTrendController)

window.Stimulus = application
