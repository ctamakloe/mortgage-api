class CreateAssessments < ActiveRecord::Migration[8.1]
  create_table :assessments do |t|
    t.references :mortgage_application, null: false, foreign_key: true
    t.integer :version, null: false
    t.string :decision, null: false
    t.jsonb :metrics
    t.jsonb :failures
    t.text :explanation
    t.datetime :computed_at, null: false

    t.index [:mortgage_application_id, :version], unique: true
    t.index [:mortgage_application_id, :computed_at]

    t.timestamps
  end
end
