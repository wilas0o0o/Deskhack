class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  # ログイン用の疑似カラム
  attr_accessor :login
  mount_uploader :avatar, AvatarUploader

  has_many :posts, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :post_comments, dependent: :destroy

  has_many :active_relationships,
            class_name: "Relationship", foreign_key: "follower_id", dependent: :destroy
  has_many :followings, through: "active_relationships", source: :followed
  has_many :passive_relationships,
            class_name: "Relationship", foreign_key: "followed_id", dependent: :destroy
  has_many :followers, through: "passive_relationships", source: :follower

  has_many :active_notifications,
            class_name: "Notification", foreign_key: "visitor_id", dependent: :destroy
  has_many :passive_notifications,
            class_name: "Notification", foreign_key: "visited_id", dependent: :destroy

  validates :name, presence: true, length: { maximum: 20 }
  validates :username,
    uniqueness: true,
    length: { minimum: 5, maximum: 15 },
    format: { with: /\A[a-z0-9]+\z/, message: "は半角英数字で入力してください" }

  # ログイン時、username or email でログインできるようにする
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(
        [
          "username = :value OR lower(email) = lower(:value)",
          { :value => login },
        ]
      ).first
    else
      where(conditions).first
    end
  end

  # すでにフォローしているかどうか
  def followings?(user)
    followings.include?(user)
  end

  # フォローするメソッド
  def follow(user)
    unless self == user
      active_relationships.create(followed_id: user.id)
    end
  end

  # フォローを外すメソッド
  def unfollow(user)
    active_relationships.find_by(followed_id: user.id).destroy
  end

  # 検索メソッド
  def self.search_for(content)
    User.where('name LIKE ?', '%' + content + '%')
  end

  # フォローの通知を作成して保存
  def create_notification_follow!(current_user)
    # 同じユーザーが同じユーザーに連続でフォローしても通知が行かないように通知済みか検索
    temp = Notification.where(
      [
        "visitor_id = ? and visited_id = ? and action = ?",
        current_user.id, id, "follow",
      ]
    )
    # 既にフォローされてない場合、通知レコードを作成
    if temp.blank?
      notification = current_user.active_notifications.new(
        visited_id: id,
        action: "follow"
      )
      # 不備がなければ保存する
      notification.save if notification.valid?
    end
  end

  def self.guest
    find_or_create_by!(name: 'guest_user', username: 'guest', email: 'guest@example.com') do |user|
      user.password = SecureRandom.urlsafe_base64
      user.name = 'guest_user'
    end
  end
end
