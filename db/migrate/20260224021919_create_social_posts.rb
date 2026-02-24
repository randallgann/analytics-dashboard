class CreateSocialPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :social_posts do |t|
      t.string   :platform,      null: false
      t.string   :external_id,   null: false
      t.string   :title,         null: false
      t.string   :url
      t.string   :author
      t.integer  :score,         default: 0
      t.integer  :comment_count, default: 0
      t.string   :subreddit
      t.datetime :published_at
      t.datetime :fetched_at,    null: false

      t.timestamps
    end

    add_index :social_posts, [:platform, :external_id], unique: true
    add_index :social_posts, :platform
    add_index :social_posts, :published_at
  end
end
