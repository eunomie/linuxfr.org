# == Schema Information
# Schema version: 20090110185148
#
# Table name: forums
#
#  id         :integer(4)      not null, primary key
#  state      :string(255)     default("active"), not null
#  title      :string(255)
#  position   :integer(4)
#  created_at :datetime
#  updated_at :datetime
#

class Forum < ActiveRecord::Base
  acts_as_list

  has_many :posts

  named_scope :sorted, :order => "position ASC"

  validates_presence_of :title, :message => "Le titre est obligatoire"
end