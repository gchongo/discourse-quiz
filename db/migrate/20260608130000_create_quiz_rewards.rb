# frozen_string_literal: true

class CreateQuizRewards < ActiveRecord::Migration[7.2]
  def up
    create_rewards_table
    create_claims_table
    ensure_rewards_indexes
    ensure_claims_indexes
  end

  def down
    drop_table :discourse_quiz_reward_claims, if_exists: true
    drop_table :discourse_quiz_rewards, if_exists: true
  end

  private

  def create_rewards_table
    return if table_exists?(:discourse_quiz_rewards)

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
  end

  def create_claims_table
    return if table_exists?(:discourse_quiz_reward_claims)

    create_table :discourse_quiz_reward_claims do |t|
      t.integer :user_id, null: false
      t.bigint :reward_id, null: false
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
  end

  def ensure_rewards_indexes
    return unless table_exists?(:discourse_quiz_rewards)

    add_index :discourse_quiz_rewards, :active, if_not_exists: true
    add_index :discourse_quiz_rewards, :position, if_not_exists: true
  end

  def ensure_claims_indexes
    return unless table_exists?(:discourse_quiz_reward_claims)

    add_index :discourse_quiz_reward_claims,
              %i[user_id reward_id],
              unique: true,
              if_not_exists: true
    add_index :discourse_quiz_reward_claims, :status, if_not_exists: true
    add_index :discourse_quiz_reward_claims, :reward_id, if_not_exists: true
  end
end
