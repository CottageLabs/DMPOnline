class Template < ActiveRecord::Base
  belongs_to :organisation
  has_many :phases, :order => 'position ASC'
  has_many :editions, :through => :phases
  has_many :questions, :through => :editions
  has_many :template_instances
  has_paper_trail
  
  accepts_nested_attributes_for :phases, :allow_destroy => true, :reject_if => :phase_empty
  attr_accessible :organisation_id, :name, :url, :description, :constraint_limit, :constraint_text, :sword_sd_uri, :phases_attributes
  validates :name, :organisation, :presence => true
  validates_presence_of :phases, :message => I18n.t('dmp.require_phase')
   
  def self.dcc_checklist
    where(:checklist => true)
    .first
  end
  
  def make_checklist(dcc_id)
    Template.where(checklist: true).update_all(checklist: false)
    if self.organisation_id == dcc_id
      self.checklist = true
      self.save!
    end
  end
  
  
  protected
  
  def phase_empty(attributes)
    Sanitize.clean(atttributes['phase']).blank?
  end

end
