# frozen_string_literal: true

# AI Voice Tools Registry
# Central registry of available tools for voice AI execution
# Each tool has strict schema definition

module AiVoiceTools
  # Tool definitions for OpenAI function calling format
  TOOLS = [
    {
      type: "function",
      function: {
        name: "generate_content",
        description: "Generate social media content (posts, tweets, captions). Creates text content that can be published to social platforms.",
        parameters: {
          type: "object",
          properties: {
            topic: {
              type: "string",
              description: "The main topic or subject for the content"
            },
            platform: {
              type: "string",
              enum: ["twitter", "facebook", "instagram", "linkedin", "general"],
              description: "Target social media platform"
            },
            tone: {
              type: "string",
              enum: ["professional", "casual", "funny", "inspirational", "informative"],
              description: "Tone of the content"
            },
            content_type: {
              type: "string",
              enum: ["post", "thread", "caption", "announcement"],
              description: "Type of content to generate"
            }
          },
          required: ["topic"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "generate_image",
        description: "Generate AI images using the configured image generation service. Creates visuals for social media posts.",
        parameters: {
          type: "object",
          properties: {
            prompt: {
              type: "string",
              description: "Detailed description of the image to generate"
            },
            style: {
              type: "string",
              enum: ["photorealistic", "illustration", "abstract", "logo", "banner"],
              description: "Style of the image"
            },
            size: {
              type: "string",
              enum: ["square", "landscape", "portrait"],
              description: "Aspect ratio of the image"
            }
          },
          required: ["prompt"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "generate_video",
        description: "Generate AI videos using the configured video generation service. Creates short videos for social media.",
        parameters: {
          type: "object",
          properties: {
            topic: {
              type: "string",
              description: "Topic or concept for the video"
            },
            duration: {
              type: "integer",
              enum: [5, 10, 15, 30],
              description: "Duration in seconds"
            },
            style: {
              type: "string",
              enum: ["realistic", "animated", "cinematic", "social"],
              description: "Style of the video"
            }
          },
          required: ["topic"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "schedule_post",
        description: "Schedule a social media post for future publishing. Content must be approved before scheduling.",
        parameters: {
          type: "object",
          properties: {
            content: {
              type: "string",
              description: "The post content/text"
            },
            platform: {
              type: "string",
              enum: ["twitter", "facebook", "instagram", "linkedin"],
              description: "Target platform"
            },
            scheduled_time: {
              type: "string",
              description: "When to publish (ISO 8601 format, e.g., 2024-01-15T10:00:00Z)"
            },
            media_urls: {
              type: "array",
              items: { type: "string" },
              description: "Optional URLs to images or videos to attach"
            }
          },
          required: ["content", "platform", "scheduled_time"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "create_campaign",
        description: "Create a new marketing campaign with goals and settings.",
        parameters: {
          type: "object",
          properties: {
            name: {
              type: "string",
              description: "Campaign name"
            },
            description: {
              type: "string",
              description: "Campaign description and goals"
            },
            target_audience: {
              type: "string",
              description: "Target audience description"
            },
            budget: {
              type: "number",
              description: "Campaign budget in USD"
            },
            start_date: {
              type: "string",
              description: "Start date (YYYY-MM-DD)"
            },
            end_date: {
              type: "string",
              description: "End date (YYYY-MM-DD)"
            }
          },
          required: ["name", "description"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "analyze_performance",
        description: "Analyze the performance of social media posts or campaigns.",
        parameters: {
          type: "object",
          properties: {
            timeframe: {
              type: "string",
              enum: ["7days", "30days", "90days", "year"],
              description: "Time period to analyze"
            },
            platform: {
              type: "string",
              enum: ["twitter", "facebook", "instagram", "linkedin", "all"],
              description: "Platform to analyze (all for combined)"
            },
            metric_type: {
              type: "string",
              enum: ["engagement", "reach", "clicks", "overview"],
              description: "Type of metrics to focus on"
            }
          },
          required: ["timeframe"]
        }
      }
    }
  ].freeze

  # Tools that require user confirmation before execution
  CONFIRMATION_REQUIRED = %w[
    generate_video
    schedule_post
    create_campaign
  ].freeze

  # Check if a tool requires confirmation
  def self.requires_confirmation?(tool_name)
    CONFIRMATION_REQUIRED.include?(tool_name)
  end
end
