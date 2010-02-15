# == Schema Information
#
# Table name: comments
#
#  id                :integer(4)      not null, primary key
#  node_id           :integer(4)
#  user_id           :integer(4)
#  state             :string(255)     default("published"), not null
#  title             :string(255)
#  body              :text
#  wiki_body         :text
#  score             :integer(4)      default(0)
#  answered_to_self  :boolean(1)      default(FALSE)
#  materialized_path :string(1022)
#  created_at        :datetime
#  updated_at        :datetime
#

# The users can comment any content.
# Those comments are threaded and can be noted.
#
class Comment < ActiveRecord::Base
  belongs_to :user
  belongs_to :node, :touch => :last_commented_at, :counter_cache => :comments_count
  has_many :relevances

  delegate :content, :content_type, :to => :node

  attr_accessible :title, :wiki_body, :node_id, :parent_id

  scope :published,    where(:state => 'published')
  scope :descendants,  lambda { |path| where("materialized_path LIKE ?", "#{path}_%") }
  scope :on_dashboard, published.where(:answered_to_self => false).order('created_at DESC')
  scope :footer,       published.order('created_at DESC').limit(12)

  validates_presence_of :title,     :message => "Le titre est obligatoire"
  validates_presence_of :wiki_body, :message => "Vous ne pouvez pas poster un commentaire vide"

  wikify_attr :body

### Sphinx ####

# TODO Rails 3
#   define_index do
#     indexes title, body
#     indexes user.name, :as => :user
#     where "state = 'published'"
#     set_property :field_weights => { :title => 5, :user => 2, :body => 1 }
#     set_property :delta => :datetime, :threshold => 75.minutes
#   end

### Reading status ###

  # Returns true if this comment has been read by the given user,
  # but also for anonymous users
  def read_by?(user)
    return true if user.nil?
    r = Reading.where(:user_id => user.id, :node_id => node_id).first
    r && r.updated_at >= created_at
  end

### Threads ###

  PATH_SIZE = 12  # Each id in the materialized_path is coded on 12 chars
  MAX_DEPTH = 1022 / PATH_SIZE

  after_create :generate_materialized_path
  def generate_materialized_path
    parent = Comment.find(parent_id) if parent_id.present?
    parent_path = parent ? parent.materialized_path : ''
    self.materialized_path = "%s%0#{PATH_SIZE}d" % [parent_path, self.id]
    self.answered_to_self  = answer_to_self?
    save
  end

  def parent_id
    @parent_id ||= materialized_path && materialized_path[-2 * PATH_SIZE .. - PATH_SIZE - 1].to_i
    @parent_id
  end

  def parent_id=(parent_id)
    @parent_id = parent_id
    return if parent_id.blank?
    parent = Comment.find(parent_id)
    self.title ||= parent ? "Re: #{parent.title}" : ''
  end

  def depth
    (materialized_path.length / PATH_SIZE) - 1
  end

  def root?
    depth == 0
  end

  def answer_to_self?
    return false if root?
    ret = Comment.where(:node_id => node_id, :user_id => user_id).
                  where("LOCATE(materialized_path, ?) > 0", self.materialized_path).
                  where("id != ?", self.id).
                  exists?
  end

### Calculations ###

  before_create :default_score
  def default_score
    self.score = Math.log10(user.account.karma).to_i - 1
  end

  def nb_answers
    self.class.published.descendants(materialized_path).count
  end

  def last_answer
    self.class.published.descendants(materialized_path).order('created_at DESC').first
  end

### ACL ###

  def readable_by?(user)
    state != 'deleted' || (user && user.admin?)
  end

  def creatable_by?(user)
    node && node.content && node.content.commentable_by?(user)
  end

  def editable_by?(user)
    user && (user.moderator? || user.admin?)
  end

  def deletable_by?(user)
    user && (user.moderator? || user.admin?)
  end

  def votable_by?(user)
    user && !deleted? && self.user != user &&
        (Time.now - created_at) < 3.months &&
        user.account.nb_votes > 0          &&
        !user.relevances.exists?(:comment_id => id)
  end

### Workflow ###

  def mark_as_deleted
    self.state = 'deleted'
    save
  end

  def deleted?
    state == 'deleted'
  end

### Presentation ###

  def user_name
    user.try :name
  end

end
