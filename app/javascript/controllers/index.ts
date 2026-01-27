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
import ScheduledPostNewController from "./scheduled_post_new_controller"
import CalendarController from "./calendar_controller"
import PwaInstallController from "./pwa_install_controller"
import MobileWebviewController from "./mobile_webview_controller"
import ScheduledPostsController from "./scheduled_posts_controller"

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
application.register("scheduled-post-new", ScheduledPostNewController)
application.register("calendar", CalendarController)
application.register("pwa-install", PwaInstallController)
application.register("mobile-webview", MobileWebviewController)
application.register("scheduled-posts", ScheduledPostsController)

window.Stimulus = application
