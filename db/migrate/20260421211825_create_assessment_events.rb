class CreateAssessmentEvents < ActiveRecord::Migration[8.1]
  create_table :assessment_events do |t|
    t.references :assessment, null: false, foreign_key: true
    t.string :event_type, null: false
    t.jsonb :payload, default: {}
    t.timestamps
  end

  add_index :assessment_events, :event_type
end
