# AI Tool Definitions - Define what GPT can do in your app
#
# Define tools using OpenAI function calling format:
# https://platform.openai.com/docs/guides/function-calling
#
# Each tool should:
# - Have a unique name (snake_case)
# - Have a clear description of what it does
# - Define required parameters with types and descriptions
#
# Example usage:
#   tools = AiToolDefinitions.for_user(current_user)
#   LlmService.new(prompt: "...", tools: tools, tool_handler: handler)
module AiToolDefinitions
  # Risk levels for tool execution
  # LOW: Auto execute
  # MEDIUM: Auto execute but notify user
  # HIGH: Require confirmation before execution
  RISK_LEVELS = {
    # Content creation - medium risk (auto-create drafts)
    create_post: :medium,
    create_content: :medium,
    generate_image: :medium,
    
    # Video - HIGH risk (requires confirmation before execution)
    generate_video: :high,
    
    # Publishing - high risk (requires confirmation)
    schedule_post: :high,
    publish_post: :high,
    publish_content: :high,
    share_to_social: :high,
    
    # Reading/retrieving - low risk
    list_recent_posts: :low,
    get_campaigns: :low,
    get_analytics: :low,
    get_user_stats: :low,
    generate_content_idea: :low,
    get_social_accounts: :low,
    get_post_results: :low,
    get_scheduled_tasks: :low,
    
    # Voice - low risk
    transcribe_audio: :low,
    synthesize_speech: :low,
    
    # Scheduling - medium risk
    schedule_task: :medium,
    create_scheduled_task: :medium
  }.freeze

  # Get risk level for a tool
  def self.risk_level(tool_name)
    RISK_LEVELS[tool_name.to_sym] || :medium
  end

  # Check if tool requires confirmation
  def self.requires_confirmation?(tool_name, user = nil)
    risk = risk_level(tool_name)
    return false if risk == :low
    return false if risk == :medium # Medium auto-executes
    
    # High risk - check user's auto-approve setting
    if user&.respond_to?(:settings) && user.settings&.dig(:auto_approve_high_risk)
      return false
    end
    
    risk == :high
  end

  # Get tool definitions for a specific user
  # Only include tools the user has access to
  def self.for_user(user)
    base_tools + user_specific_tools(user)
  end

  # Core tools available to all users
  def self.base_tools
    [
      # === Content Creation ===
      {
        type: "function",
        function: {
          name: "create_post",
          description: "Create a new social media post with text content. The post is saved as a draft.",
          parameters: {
            type: "object",
            properties: {
              content: {
                type: "string",
                description: "The main text content of the post"
              },
              platform: {
                type: "string",
                enum: ["twitter", "facebook", "instagram", "linkedin"],
                description: "Target social media platform"
              }
            },
            required: ["content"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "generate_image",
          description: "Generate an image using AI. Returns an image URL that can be used in posts.",
          parameters: {
            type: "object",
            properties: {
              prompt: {
                type: "string",
                description: "Detailed description of the image to generate"
              },
              size: {
                type: "string",
                enum: ["1024x1024", "1792x1024", "1024x1792"],
                description: "Image dimensions (default: 1024x1024)"
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
          description: "Generate a video using AI. Returns a task ID that can be polled for the video URL.",
          parameters: {
            type: "object",
            properties: {
              prompt: {
                type: "string",
                description: "Detailed description of the video to generate"
              },
              duration: {
                type: "string",
                enum: ["5", "10", "15"],
                description: "Video duration in seconds"
              },
              aspect_ratio: {
                type: "string",
                enum: ["16:9", "9:16"],
                description: "Aspect ratio (16:9 landscape, 9:16 vertical)"
              }
            },
            required: ["prompt"]
          }
        }
      },
      
      # === Social Media Posting (Postforme) ===
      {
        type: "function",
        function: {
          name: "schedule_post",
          description: "Schedule a post to be published at a specific date and time",
          parameters: {
            type: "object",
            properties: {
              content: {
                type: "string",
                description: "The text content of the post"
              },
              platform: {
                type: "string",
                enum: ["twitter", "facebook", "instagram", "linkedin"],
                description: "Target social media platform"
              },
              scheduled_at: {
                type: "string",
                description: "When to publish the post (ISO 8601 format, e.g., '2024-06-15T14:30:00Z')"
              }
            },
            required: ["content", "scheduled_at"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "publish_post",
          description: "Publish a post immediately to social media",
          parameters: {
            type: "object",
            properties: {
              content: {
                type: "string",
                description: "The text content of the post"
              },
              platform: {
                type: "string",
                enum: ["twitter", "facebook", "instagram", "linkedin"],
                description: "Target social media platform"
              },
              media_urls: {
                type: "array",
                items: { type: "string" },
                description: "Array of media URLs to attach to the post"
              }
            },
            required: ["content"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_social_accounts",
          description: "Get list of connected social media accounts",
          parameters: {
            type: "object",
            properties: {
              platform: {
                type: "string",
                enum: ["twitter", "facebook", "instagram", "linkedin", "tiktok"],
                description: "Filter by platform (optional)"
              }
            }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_post_results",
          description: "Get the results/status of a posted social media post",
          parameters: {
            type: "object",
            properties: {
              post_id: {
                type: "string",
                description: "The ID of the post to check"
              }
            },
            required: ["post_id"]
          }
        }
      },
      
      # === Analytics & Reporting ===
      {
        type: "function",
        function: {
          name: "list_recent_posts",
          description: "Get a list of recent posts or drafts",
          parameters: {
            type: "object",
            properties: {
              status: {
                type: "string",
                enum: ["draft", "scheduled", "published"],
                description: "Filter by post status"
              },
              limit: {
                type: "integer",
                description: "Maximum number of posts to return (default: 10)"
              }
            }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_campaigns",
          description: "Get marketing campaigns",
          parameters: {
            type: "object",
            properties: {
              status: {
                type: "string",
                enum: ["active", "completed", "draft"],
                description: "Filter by campaign status"
              }
            }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_analytics",
          description: "Get performance analytics for posts or campaigns",
          parameters: {
            type: "object",
            properties: {
              metric_type: {
                type: "string",
                enum: ["engagement", "reach", "clicks", "overview"],
                description: "Type of analytics to retrieve"
              },
              days: {
                type: "integer",
                description: "Number of days to look back (default: 7)"
              }
            }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "generate_content_idea",
          description: "Generate content ideas for a specific topic or platform",
          parameters: {
            type: "object",
            properties: {
              topic: {
                type: "string",
                description: "Topic or theme for content ideas"
              },
              platform: {
                type: "string",
                enum: ["twitter", "facebook", "instagram", "linkedin", "any"],
                description: "Target platform (default: any)"
              },
              count: {
                type: "integer",
                description: "Number of ideas to generate (default: 3)"
              }
            }
          }
        }
      },
      
      # === Scheduling & Tasks ===
      {
        type: "function",
        function: {
          name: "schedule_task",
          description: "Schedule a recurring task (e.g., daily content generation, weekly analytics)",
          parameters: {
            type: "object",
            properties: {
              task_type: {
                type: "string",
                enum: ["content_generation", "performance_analysis", "trends_analysis", "ai_insights"],
                description: "Type of task to schedule"
              },
              schedule: {
                type: "string",
                enum: ["daily", "weekly", "monthly"],
                description: "How often to run the task"
              },
              config: {
                type: "object",
                description: "Task-specific configuration"
              }
            },
            required: ["task_type", "schedule"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_scheduled_tasks",
          description: "Get list of scheduled/recurring tasks",
          parameters: {
            type: "object",
            properties: {
              status: {
                type: "string",
                enum: ["active", "paused", "completed"],
                description: "Filter by task status"
              }
            }
          }
        }
      },
      
      # === Voice (Whisper + TTS) ===
      {
        type: "function",
        function: {
          name: "transcribe_audio",
          description: "Transcribe spoken audio to text using speech recognition",
          parameters: {
            type: "object",
            properties: {
              language: {
                type: "string",
                description: "Language code (e.g., 'en', 'es', 'fr')"
              }
            }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "synthesize_speech",
          description: "Convert text to speech for voice output",
          parameters: {
            type: "object",
            properties: {
              text: {
                type: "string",
                description: "Text to convert to speech"
              },
              voice_id: {
                type: "string",
                description: "Voice ID to use (optional)"
              }
            },
            required: ["text"]
          }
        }
      }
    ]
  end

  # Tools specific to user (based on their account, subscription, etc.)
  def self.user_specific_tools(user)
    # Can be extended based on user permissions, connected accounts, etc.
    []
  end

  # Tools for admin users only
  def self.admin_tools
    [
      {
        type: "function",
        function: {
          name: "get_user_stats",
          description: "Get statistics about user accounts (admin only)",
          parameters: {
            type: "object",
            properties: {
              period: {
                type: "string",
                enum: ["today", "week", "month", "all"],
                description: "Time period for statistics"
              }
            }
          }
        }
      }
    ]
  end
end
