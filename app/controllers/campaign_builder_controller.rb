class CampaignBuilderController < ApplicationController
  before_action :authenticate_user!

  def index
    @templates = CampaignTemplate.active.order(category: :asc, name: :asc)
    @campaigns = current_user.campaigns.order(created_at: :desc).limit(10)
  end

  def select_template
    @template = CampaignTemplate.active.find(params[:template_id])
    render partial: 'template_details', locals: { template: @template }
  end

  def customize_form
    @template = CampaignTemplate.active.find(params[:template_id])
    @customizations = {
      product_name: '',
      promo_code: '',
      brand_name: current_user.name || '',
      discount_percent: '50',
      holiday_name: 'Holiday Sale',
      end_date: (Date.current + 7).strftime('%Y-%m-%d'),
      launch_date: Date.current.strftime('%Y-%m-%d')
    }
    render partial: 'customize_form', locals: { template: @template, customizations: @customizations }
  end

  def customize
    @template = CampaignTemplate.active.find(params[:template_id])
    @customizations = {
      product_name: params[:product_name] || '',
      promo_code: params[:promo_code] || '',
      brand_name: params[:brand_name] || current_user.name || 'Our Brand',
      discount_percent: params[:discount_percent] || '50',
      holiday_name: params[:holiday_name] || 'Holiday Sale',
      end_date: params[:end_date] || (Date.current + 7).strftime('%B %d, %Y')
    }
  end

  def preview
    @template = CampaignTemplate.active.find(params[:template_id])
    @customizations = {
      product_name: params[:product_name] || '',
      promo_code: params[:promo_code] || '',
      brand_name: params[:brand_name] || current_user.name || 'Our Brand',
      discount_percent: params[:discount_percent] || '50',
      holiday_name: params[:holiday_name] || 'Holiday Sale',
      end_date: params[:end_date] || (Date.current + 7).strftime('%B %d, %Y')
    }
    
    @preview_days = generate_preview_days(@template, @customizations)
    
    render partial: 'preview', locals: { template: @template, days: @preview_days, customizations: @customizations }
  end

  def create
    @template = CampaignTemplate.active.find(params[:template_id])
    
    customizations = {
      product_name: params[:product_name] || '',
      promo_code: params[:promo_code] || '',
      brand_name: params[:brand_name] || current_user.name || 'Our Brand',
      discount_percent: params[:discount_percent] || '50',
      holiday_name: params[:holiday_name] || 'Holiday Sale',
      end_date: params[:end_date] || (Date.current + 7).strftime('%B %d, %Y'),
      launch_date: params[:launch_date] || Date.current.strftime('%B %d, %Y')
    }

    campaign = current_user.campaigns.create!(
      name: "#{@template.name} - #{customizations[:launch_date]}",
      description: @template.description,
      start_date: Date.parse(customizations[:launch_date]),
      end_date: Date.parse(customizations[:launch_date]) + @template.duration_days.days - 1,
      status: 'draft',
      goal: 'engagement',
      platforms: @template.platforms,
      campaign_type: @template.category == 'product' ? 'product_launch' : 'seasonal'
    )

    days_data = generate_preview_days(@template, customizations)
    
    days_data.each do |day_data|
      day_data[:contents].each do |content_data|
        content = campaign.contents.create!(
          title: content_data[:title],
          body: content_data[:caption],
          content_type: content_data[:content_type],
          platform: content_data[:platform],
          scheduled_at: parse_time_string(day_data[:scheduled_date], content_data[:post_time]),
          status: 'draft'
        )
      end
    end

    redirect_to campaign_path(campaign), notice: "Campaign created from #{@template.name} template!"
  rescue => e
    Rails.logger.error "Campaign Builder Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to campaign_builder_index_path, alert: "Failed to create campaign: #{e.message}"
  end

  def ai_customize
    @template = CampaignTemplate.active.find(params[:template_id])
    @day_index = params[:day_index].to_i
    @platform = params[:platform]
    @base_caption = params[:caption]
    @element_id = params[:element_id] || "caption-#{@day_index}-#{@platform}"
    
    customizations = {
      product_name: params[:product_name] || '',
      promo_code: params[:promo_code] || '',
      brand_name: params[:brand_name] || current_user.name || 'Our Brand'
    }

    result = LlmService.generate_content(
      prompt: build_ai_customization_prompt(@template, @day_index, @platform, @base_caption, customizations),
      user_id: current_user.id,
      content_type: 'caption'
    )

    if result[:success]
      @customized_caption = result[:content]['body'] || result[:content].to_s
      @customized_caption = @customized_caption.gsub(/^["']|["']$/, '').strip
      @status = :success
    else
      @error_message = result[:error] || 'Failed to customize caption'
      @status = :error
    end
    
    render "ai_customize.turbo_stream.erb"
  rescue LlmService::ApiError => e
    @error_message = e.message
    @status = :api_error
    render "ai_customize.turbo_stream.erb"
  rescue => e
    Rails.logger.error "AI Customization Error: #{e.message}"
    @error_message = e.message
    @status = :error
    render "ai_customize.turbo_stream.erb"
  end

  private

  def generate_preview_days(template, customizations)
    launch_date = Date.parse(customizations[:launch_date] || Date.current.strftime('%Y-%m-%d'))
    
    template.days.map do |day|
      day_date = launch_date + (day['day'].to_i - 1).days
      
      contents = template.platforms.first(3).map do |platform|
        caption = replace_placeholders(day['caption_template'], customizations)
        
        {
          title: day['title'],
          caption: caption,
          platform: platform,
          post_time: day['post_time'],
          content_type: map_content_type(day['content_type']),
          theme: day['theme']
        }
      end

      {
        day: day['day'],
        title: day['title'],
        theme: day['theme'],
        scheduled_date: day_date.strftime('%B %d, %Y'),
        contents: contents
      }
    end
  end

  def replace_placeholders(template, customizations)
    template
      .gsub('[PRODUCT_NAME]', customizations[:product_name].presence || '[Product Name]')
      .gsub('[PROMO_CODE]', customizations[:promo_code].presence || '[PROMO CODE]')
      .gsub('[BRAND_NAME]', customizations[:brand_name].presence || '[Brand Name]')
      .gsub('[DISCOUNT_PERCENT]', customizations[:discount_percent].presence || '50')
      .gsub('[HOLIDAY_NAME]', customizations[:holiday_name].presence || 'Holiday Sale')
      .gsub('[END_DATE]', customizations[:end_date].presence || (Date.current + 7).strftime('%B %d, %Y'))
  end

  def parse_time_string(date, time_str)
    date.to_s + ' ' + time_str
  end

  def map_content_type(content_type)
    type_map = {
      'teaser' => 'post', 'pain_point' => 'post', 'announcement' => 'post',
      'social_proof' => 'post', 'features' => 'post', 'urgency' => 'post',
      'last_chance' => 'post', 'countdown' => 'post', 'sneak_peek' => 'post',
      'sale_launch' => 'post', 'spotlight' => 'post', 'gift_guide' => 'post',
      'introduction' => 'post', 'mission' => 'post', 'bts' => 'post',
      'process' => 'post', 'community' => 'post', 'milestone' => 'post',
      'testimonial' => 'post', 'educational' => 'post', 'partnership' => 'post',
      'culture' => 'post', 'innovation' => 'post', 'cause' => 'post',
      'appreciation' => 'post', 'recap' => 'post', 'hint' => 'post',
      'preview' => 'post', 'launch' => 'post', 'motivation' => 'post',
      'tip' => 'post', 'question' => 'post', 'feature' => 'post',
      'story' => 'post', 'success' => 'post', 'wrap_up' => 'post'
    }
    type_map[content_type] || 'post'
  end

  def build_ai_customization_prompt(template, day_index, platform, base_caption, customizations)
    day = template.days[day_index]
    
    <<~PROMPT
      You are a social media marketing expert. Customize the following caption for a #{platform} post.
      
      Template Day: #{day['title']}
      Day Theme: #{day['theme']}
      Campaign Theme: #{template.theme}
      
      Current Caption:
      #{base_caption}
      
      Product/Brand Details:
      - Product Name: #{customizations[:product_name].presence || 'Not specified'}
      - Brand Name: #{customizations[:brand_name]}
      - Promo Code: #{customizations[:promo_code].presence || 'Not specified'}
      
      Requirements:
      1. Keep the same message and tone
      2. Make it sound natural for #{platform}
      3. Keep the same length or shorter
      4. Use engaging language appropriate for the platform
      5. Keep any emojis that fit naturally
      
      Return ONLY the customized caption, nothing else. Start directly with the caption.
    PROMPT
  end
end
