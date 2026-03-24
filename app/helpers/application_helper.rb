module ApplicationHelper
  def page_title_for(controller_name)
    case controller_name
    when 'calendar'
      content_tag(:div, class: "flex items-center justify-between") do
        concat(content_tag(:div) do
          concat(content_tag(:h1, "Content Calendar", class: "text-2xl font-bold text-gray-900 dark:text-white"))
          concat(content_tag(:p, @current_view.capitalize + " view • " + @current_date.strftime("%B %Y"), class: "text-sm text-gray-600 dark:text-gray-400 mt-1"))
        end)
        concat(render partial: 'shared/page_title_actions', locals: { view: @current_view })
      end
    when 'scheduled_posts'
      content_tag(:div, class: "flex items-center justify-between") do
        concat(content_tag(:div) do
          concat(content_tag(:h1, "Scheduled Posts", class: "text-2xl font-bold text-gray-900 dark:text-white"))
          concat(content_tag(:p, "Manage and optimize your content scheduling", class: "text-sm text-gray-600 dark:text-gray-400 mt-1"))
        end)
        concat(render partial: 'shared/scheduled_posts_title_actions')
      end
    else
      ""
    end
  end

  def platform_icon(platform)
    icons = {
      'instagram' => '📸',
      'twitter' => '𝕏',
      'x' => '𝕏',
      'facebook' => '📘',
      'linkedin' => '💼',
      'tiktok' => '🎵',
      'youtube' => '▶️',
      'pinterest' => '📌',
      'bluebird' => '🐦',
      'threads' => '@',
      'general' => '📱'
    }
    icons[platform&.downcase] || '📱'
  end
end
