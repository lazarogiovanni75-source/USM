module Ai
  class ToolExecutor
    class ToolNotFoundError < StandardError; end
    class ToolExecutionError < StandardError; end
    
    def self.call(tool_name, parameters, user:, campaign: nil)
      Rails.logger.info "[ToolExecutor] Executing #{tool_name} with params: #{parameters.inspect}"
      
      tool_class_name = "Ai::Tools::#{tool_name.camelize}"
      
      begin
        tool_class = tool_class_name.constantize
      rescue NameError
        raise ToolNotFoundError, "Tool '#{tool_name}' not found. Available tools: #{Ai::ToolRegistry.tool_names.join(', ')}"
      end
      
      begin
        result = tool_class.call(
          parameters.merge(user: user, campaign: campaign)
        )
        Rails.logger.info "[ToolExecutor] #{tool_name} completed successfully"
        result
      rescue => e
        Rails.logger.error "[ToolExecutor] #{tool_name} failed: #{e.message}"
        raise ToolExecutionError, "Tool '#{tool_name}' failed: #{e.message}"
      end
    end
    
    # Execute multiple tools in sequence
    def self.execute_chain(tool_calls, user:, campaign: nil)
      results = []
      
      tool_calls.each do |tool_call|
        tool_name = tool_call[:tool_name]
        parameters = tool_call[:parameters]
        
        result = call(tool_name, parameters, user: user, campaign: campaign)
        results << { tool_name: tool_name, result: result }
      end
      
      results
    end
  end
end
