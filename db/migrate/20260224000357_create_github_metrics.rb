class CreateGithubMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :github_metrics do |t|
      t.string :metric_type, null: false
      t.decimal :value, null: false, precision: 15, scale: 4
      t.date :recorded_on, null: false

      t.timestamps
    end

    add_index :github_metrics, [:metric_type, :recorded_on], unique: true
  end
end
