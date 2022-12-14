class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true
  delegate :name, to: :user, prefix: true
  validates_presence_of :body
end
