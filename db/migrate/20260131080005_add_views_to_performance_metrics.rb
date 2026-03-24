class AddViewsToPerformanceMetrics < ActiveRecord::Migration[7.2]
  def change
    add_column :performance_metrics, :views, :integer, default: 0
  end
end
