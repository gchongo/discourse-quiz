# frozen_string_literal: true

class CreateQuizRewards < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_quiz_rewards do |t|
      t.string :name, null: false
      t.text :description
      t.string :category
      t.string :image_url
      t.integer :points_threshold, null: false, default: 0
      t.integer :stock
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :discourse_quiz_rewards, :active
    add_index :discourse_quiz_rewards, :position

    create_table :discourse_quiz_reward_claims do |t|
      t.integer :user_id, null: false
      t.bigint :reward_id, null: false
      t.string :status, null: false, default: "pending"
      t.timestamps
    end

    add_index :discourse_quiz_reward_claims, %i[user_id reward_id], unique: true
    add_index :discourse_quiz_reward_claims, :status
    add_index :discourse_quiz_reward_claims, :reward_id
  end
end
