module BrandVoiceHelper
  BRAND_VOICE_QUESTIONS = [
    {
      key: "tone",
      question: "How would you describe your overall tone?",
      options: [
        "Conversational & Friendly",
        "Professional & Authoritative",
        "Playful & Humorous",
        "Inspirational & Motivational",
        "Bold & Direct"
      ]
    },
    {
      key: "audience",
      question: "Who is your primary audience?",
      options: [
        "Entrepreneurs & Business Owners",
        "Content Creators",
        "General Consumers",
        "Corporate Professionals",
        "Young Adults / Gen Z"
      ]
    },
    {
      key: "formality",
      question: "How formal is your communication?",
      options: [
        "Very casual (slang, abbreviations ok)",
        "Casual but professional",
        "Neutral",
        "Formal but approachable",
        "Very formal"
      ]
    },
    {
      key: "humor",
      question: "How much humor do you use?",
      options: [
        "None - I keep it serious",
        "Occasional light humor",
        "Regular wit and humor",
        "Humor is central to my brand"
      ]
    },
    {
      key: "cta_style",
      question: "How do you like to end content?",
      options: [
        "Always with a question",
        "Always with a strong CTA",
        "Thought-provoking statement",
        "Soft suggestion",
        "Varies"
      ]
    },
    {
      key: "avoid",
      question: "What do you NEVER want in your content?",
      options: [
        "Corporate jargon",
        "Exclamation marks",
        "Overly salesy language",
        "Negative framing",
        "Passive voice"
      ]
    }
  ].freeze
end
