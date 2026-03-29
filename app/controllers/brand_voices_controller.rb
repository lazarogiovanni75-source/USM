class BrandVoicesController < ApplicationController
  before_action :authenticate_user!

  # GET /brand_voice
  def show
    @user = current_user
    @examples = JSON.parse(@user.brand_voice_examples || "[]")
    @answers = JSON.parse(@user.brand_voice_answers || "{}")
  end

  # POST /brand_voice/analyze
  # Sends all inputs to Claude, generates and saves Brand Voice Summary
  def analyze
    # Handle both JSON and regular parameter formats
    examples = if params[:examples_json].present?
      JSON.parse(params[:examples_json])
    elsif params[:examples].present?
      params[:examples]
    else
      []
    end

    answers = if params[:answers_json].present?
      JSON.parse(params[:answers_json])
    elsif params[:answers].present?
      params[:answers]
    else
      {}
    end

    document = params[:document] || ""

    # Build the analysis prompt
    prompt = build_analysis_prompt(examples, answers, document)

    # Call LLM API via our existing service
    response = LlmStreamJob.perform_later(
      channel_name: "brand_voice_#{current_user.id}",
      prompt: prompt,
      system: LlmPrompts::BRAND_VOICE_ANALYST,
      user_id: current_user.id
    )

    # For synchronous response, use the LLM service directly
    client = OllamaClient.new
    response_text = client.generate(prompt: prompt, system: LlmPrompts::BRAND_VOICE_ANALYST)

    # Save everything to the user
    current_user.update!(
      brand_voice_summary: response_text,
      brand_voice_examples: examples.to_json,
      brand_voice_answers: answers.to_json,
      brand_voice_document: document,
      brand_voice_generated_at: Time.current
    )

    # Track onboarding progress
    current_user.complete_onboarding_step!(:setup_brand_voice)

    # Reload the show page with updated data
    redirect_to brand_voice_path, notice: "Brand voice profile generated successfully!"
  rescue => e
    Rails.logger.error "Brand voice analysis error: #{e.message}"
    redirect_to brand_voice_path, alert: "Failed to generate brand voice: #{e.message}"
  end

  # DELETE /brand_voice/reset
  def reset
    current_user.update!(
      brand_voice_summary: nil,
      brand_voice_examples: nil,
      brand_voice_answers: nil,
      brand_voice_document: nil,
      brand_voice_generated_at: nil
    )
    redirect_to brand_voice_path, notice: "Brand voice reset successfully."
  end

  private

  def build_analysis_prompt(examples, answers, document)
    sections = []

    if examples.any?
      sections << "## Writing Examples\nHere are posts/content this person has written:\n\n#{examples.join("\n\n---\n\n")}"
    end

    if answers.any?
      sections << "## Brand Personality Answers\n#{answers.map { |q, a| "#{q}: #{a}" }.join("\n")}"
    end

    if document.present?
      sections << "## Brand Document\n#{document}"
    end

    sections << <<~PROMPT
      ## Your Task
      Based on all the above, write a Brand Voice Profile that describes:

      1. Overall tone (e.g. conversational, authoritative, playful, inspirational)
      2. Vocabulary style (simple/complex, slang, industry terms)
      3. Sentence structure (short punchy vs long descriptive)
      4. Personality traits (humor level, warmth, directness)
      5. What to always do (e.g. always use "you" not "one", always end with a CTA)
      6. What to never do (e.g. never use corporate jargon, never use exclamation marks)
      7. Example phrases or expressions they use

      Write this as clear, specific instructions that an AI can follow when generating content.
      Format: Write in second person as instructions. E.g. "Write in a warm, direct tone..."
      Length: 200-300 words maximum.
    PROMPT

    sections.join("\n\n")
  end
end
