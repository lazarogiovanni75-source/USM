class ContentTemplateVariable < ApplicationRecord
  belongs_to :content_template
  
  enum variable_type: {
    text: 'text',
    number: 'number',
    url: 'url',
    email: 'email',
    date: 'date',
    dropdown: 'dropdown',
    multiselect: 'multiselect'
  }
  
  validates :variable_name, presence: true
  validates :variable_type, presence: true
  validates :content_template, presence: true
  
  # Validation rules can be stored as JSON
  # Examples: { "required": true, "min_length": 5, "max_length": 100 }
  
  def self.create_default_variables_for_template(template)
    variables = template.extract_variables
    variables.each do |var_name|
      template.content_template_variables.create!(
        variable_name: var_name,
        variable_type: guess_variable_type(var_name),
        default_value: '',
        placeholder_text: var_name.humanize,
        validation_rules: get_default_validation_rules(var_name)
      )
    end
  end
  
  private
  
  def self.guess_variable_type(variable_name)
    case variable_name.downcase
    when /email/
      :email
    when /url|link|website/
      :url
    when /date|time|period/
      :date
    when /number|count|amount|price/
      :number
    when /option|choice|select/
      :dropdown
    else
      :text
    end
  end
  
  def self.get_default_validation_rules(variable_name)
    rules = {}
    
    case variable_name.downcase
    when /email/
      rules[:format] = :email
    when /url|link|website/
      rules[:format] = :url
    when /hashtag/
      rules[:prefix] = '#'
    when /cta/
      rules[:required] = true
    when /product_name|name/
      rules[:min_length] = 3
      rules[:max_length] = 100
    end
    
    rules
  end
end