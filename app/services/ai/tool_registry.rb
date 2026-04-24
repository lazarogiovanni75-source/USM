module Ai
  class ToolRegistry
    class UnknownToolError < StandardError; end
    
    # Campaign-specific tools for autonomous orchestration
    CAMPAIGN_TOOLS = [
      {
        type: "function",
        function: {
          name: "generate_post",
          description: "Generate a social media post with caption and hashtags. Creates a draft post in the system.",
          parameters: {
            type: "object",
            properties: {
              platform: {
                type: "string",
                enum: ["twitter", "facebook", "instagram", "linkedin"],
                description: "Target social media platform"
              },
              content_type: {
                type: "string",
                enum: ["text", "image", "video", "carousel"],
                description: "Type of content to create"
              },
              theme: {
                type: "string",
                description: "Main theme or topic for the post"
              },
              tone: {
                type: "string",
                enum: ["professional", "casual", "humor", "inspirational", "educational"],
                description: "Tone of the content"
              },
              call_to_action: {
                type: "string",
                description: "Optional call to action (e.g., 'Click the link', 'Learn more')"
              }
            },
            required: ["platform", "theme"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "generate_video",
          description: "Generate an AI video. Creates a video generation task and returns a task ID for polling.",
          parameters: {
            type: "object",
            properties: {
              prompt: {
                type: "string",
                description: "Detailed description of the video to generate"
              },
              duration: {
                type: "string",
                enum: ["5", "10", "15", "25"],
                description: "Video duration in seconds"
              },
              model: {
                type: "string",
                enum: ["bytedance/seedance-v1.5-pro/text-to-video-fast", "bytedance/seedance-v1.5-pro/image-to-video-fast"],
                description: "Video model (bytedance/seedance-v1.5-pro for text-to-video or image-to-video)"
              }
            },
            required: ["prompt"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "generate_image",
          description: "Generate an AI image for use in social media posts. Uses GPT-Image-1.5 through Atlas Cloud.",
          parameters: {
            type: "object",
            properties: {
              prompt: {
                type: "string",
                description: "Detailed description of the image to generate"
              },
              style: {
                type: "string",
                enum: ["photorealistic", "illustration", "minimalist", "vibrant", "professional"],
                description: "Image style"
              },
              size: {
                type: "string",
                enum: ["1024x1024", "1792x1024", "1024x1792"],
                description: "Image dimensions"
              }
            },
            required: ["prompt"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "schedule_post",
          description: "Schedule a post to be published at a specific date and time. Creates a scheduled post record.",
          parameters: {
            type: "object",
            properties: {
              content_id: {
                type: "integer",
                description: "ID of the content to schedule"
              },
              platform: {
                type: "string",
                enum: ["twitter", "facebook", "instagram", "linkedin"],
                description: "Target social media platform"
              },
              scheduled_at: {
                type: "string",
                description: "When to publish (ISO 8601 format, e.g., '2024-06-15T14:30:00Z')"
              }
            },
            required: ["content_id", "platform", "scheduled_at"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "publish_post",
          description: "Publish a scheduled post to social media. Finds the post and publishes via Postforme.",
          parameters: {
            type: "object",
            properties: {
              scheduled_post_id: {
                type: "integer",
                description: "ID of the scheduled post to publish"
              },
              content_id: {
                type: "integer",
                description: "ID of the content to publish"
              }
            }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "pull_performance_metrics",
          description: "Pull latest performance metrics from social platforms and store in database",
          parameters: {
            type: "object",
            properties: {
              post_id: {
                type: "integer",
                description: "Specific post ID to pull metrics for"
              },
              campaign_id: {
                type: "integer",
                description: "Campaign ID to pull metrics for all published posts"
              }
            }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "adjust_strategy",
          description: "Adjust campaign strategy parameters like tone, posting frequency, or hashtags",
          parameters: {
            type: "object",
            properties: {
              campaign_id: {
                type: "integer",
                description: "ID of the campaign to adjust"
              },
              posts_per_day: {
                type: "integer",
                description: "New posting frequency per day"
              },
              tone: {
                type: "string",
                enum: ["professional", "casual", "humor", "inspirational", "educational"],
                description: "New tone for content"
              },
              hashtags: {
                type: "string",
                description: "New hashtags to use (comma separated)"
              }
            },
            required: ["campaign_id"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "test_new_format",
          description: "Test a new content format for A/B testing purposes",
          parameters: {
            type: "object",
            properties: {
              campaign_id: {
                type: "integer",
                description: "ID of the campaign"
              },
              format: {
                type: "string",
                enum: ["video", "carousel", "story", "reel", "poll", "quiz"],
                description: "Format type to test"
              },
              description: {
                type: "string",
                description: "Description of what to test"
              }
            },
            required: ["campaign_id", "format"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_campaign_status",
          description: "Get the current status of a campaign including completed tasks and next steps",
          parameters: {
            type: "object",
            properties: {
              campaign_id: {
                type: "integer",
                description: "ID of the campaign to check"
              }
            },
            required: ["campaign_id"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "analyze_performance",
          description: "Analyze the performance of published posts and provide insights",
          parameters: {
            type: "object",
            properties: {
              campaign_id: {
                type: "integer",
                description: "ID of the campaign to analyze"
              },
              days: {
                type: "integer",
                description: "Number of days to analyze (default: 7)"
              }
            }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "complete_campaign",
          description: "Mark a campaign as completed when all desired tasks are done",
          parameters: {
            type: "object",
            properties: {
              campaign_id: {
                type: "integer",
                description: "ID of the campaign to complete"
              },
              summary: {
                type: "string",
                description: "Summary of what was accomplished"
              }
            },
            required: ["campaign_id"]
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
      {
        type: "function",
        function: {
          name: "wait",
          description: "Wait/sleep for a specified duration. Use when pacing is needed between actions.",
          parameters: {
            type: "object",
            properties: {
              seconds: {
                type: "integer",
                description: "Number of seconds to wait"
              }
            },
            required: ["seconds"]
          }
        }
      }
    ].freeze
    
    # Get all campaign tools schema
    def self.schema
      CAMPAIGN_TOOLS
    end
    
    # Get tool by name
    def self.find(tool_name)
      CAMPAIGN_TOOLS.find { |t| t[:function][:name] == tool_name }
    end
    
    # Check if tool exists
    def self.exists?(tool_name)
      CAMPAIGN_TOOLS.any? { |t| t[:function][:name] == tool_name }
    end
    
    # List all tool names
    def self.tool_names
      CAMPAIGN_TOOLS.map { |t| t[:function][:name] }
    end
  end
end
