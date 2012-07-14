class Plan < ActiveRecord::Base
  belongs_to :currency
  belongs_to :user
  # Lead organisation currently just plain text field
  # belongs_to :organisation
  has_many :template_instances
  has_many :template_instance_rights, :through => :template_instances
  has_many :templates, :through => :template_instances
  has_many :phase_edition_instances, :through => :template_instances
  has_many :answers, :through => :phase_edition_instances
  has_many :current_phase_edition_instances, :source => :phase_edition_instances, :through => :template_instances, :conditions =>  "template_instances.current_edition_id = phase_edition_instances.edition_id"
  has_many :current_answers, :source => :answers, :through => :current_phase_edition_instances 
  has_many :questions, :through => :answers


#  belongs_to :parent, :class_name => 'MyModel'
#  has_many :children, :class_name => 'MyModel', :foreign_key => 'parent_id'

  belongs_to :repository

  belongs_to :source_plan, :class_name => 'Plan', :foreign_key => 'duplicated_from_plan_id' #Rails Magic!
  has_many :duplicate_plans, :class_name => 'Plan', :foreign_key => 'duplicated_from_plan_id'

  attr_accessible :project, :currency_id, :budget, :start_date, :end_date, :lead_org, :other_orgs, :template_ids
  #New fields for repository integration
  attr_accessible :repository_id, :duplicated_from_plan_id,
    :repository_content_uri, :repository_entry_edit_uri, :repository_edit_media_uri,
    :repository_sword_edit_uri, :repository_sword_statement_uri
  
  accepts_nested_attributes_for :template_instances, :update_only => true, :allow_destroy => false

  validates_presence_of :project
  validates_presence_of :template_instances, :message => I18n.t('dmp.require_template')

  #attr_accessor :template_ids

  #before_validation :update_template_instances # MW LOOKS WRONG??
  after_save :update_template_instances     #MW FIX
  after_initialize :load_template_instances

  
  def self.for_user(user)
    # Check all template instances for access rights for provided user
    user ||= User.new
    includes(:template_instance_rights).where("plans.user_id = ? OR ? LIKE email_mask", user.id, user.email)
  end

  def question_counts
    self.answers.count(group: 'phase_edition_instances.id', conditions: 'answers.hidden = 0')
  end

  def answered_counts
    self.answers.count(group: 'phase_edition_instances.id', conditions: 'answers.answered <> 0 AND answers.hidden = 0')
  end
  
  def report_questions
    col = []
    self.current_phase_edition_instances.each do |pei|
      col += pei.report_questions
    end
    col
  end

  def user_list
    self.template_instance_rights.inject({}) do |hash, tir|
      hash.merge!(tir.email_mask => TemplateInstance::ROLES[tir.role_flags.to_i]) do |key, oldval, newval| 
        combo = []
        combo << oldval
        combo << newval
        combo.uniq.join(", ")
      end
    end
  end

  def common_rights
    ti_list = self.template_instances.collect(&:id)
    TemplateInstanceRight
      .select("email_mask, role_flags")
      .where(:template_instance_id => ti_list)
      .group("email_mask, role_flags")
      .having("count(*) = ?", ti_list.count)
  end
  
  def simple_rights?
    ti_list = self.template_instances.collect(&:id)
    tirs = TemplateInstanceRight
      .select("email_mask, role_flags")
      .where(:template_instance_id => ti_list)
      .group("email_mask, role_flags")
      .having("count(*) != ?", ti_list.count)
      .collect(&:email_mask)
    
    return tirs.size == 0
  end

  def external_writable
    !self.template_instance_rights.where(:role_flags => TemplateInstance::ROLES.index('write')).blank?
  end
  
  
  def template_ids
    @template_ids ||= template_instances.collect {|template_instance| template_instance.template_id.to_s}
  end
  
  def template_ids=value
    @template_ids = value
  end
  
  
  def load_template_instances
    @template_ids = template_instances.collect {|template_instance| template_instance.template_id.to_s} #|| []
  end
  
  protected
  

  def update_template_instances

      #For each template_instance which has an entry in template_ids, delete the record in template_ids
      template_instances.each do |template_instance|
        template_ids.delete(template_instance.template_id.to_s)
      end

      #for each entry in template_ids, create a new templaet instance
      template_ids.each do |template_id|
        template_instances.build(:template_id => template_id.to_i) unless template_id.blank?
      end
      
      #now resynchronise template_ids
      load_template_instances
#      template_ids = template_instances.collect {|template_instance| template_instance.template_id}

  end



  #after_save callback to handle template_instances
  def update_template_instances_OLD
    
#    logger.info "NOW IN update_template_instances ---------------------- "
#    logger.info "self.template_ids ---------------------- "    
#    logger.info self.template_ids
    
    if !self.template_ids.nil? && self.template_ids.is_a?(Array)
      
#      logger.info "if ( !self.template_ids.nil? && self.template_ids.is_a?(Array)) is true ---------------------- "    
      
      self.template_instances.each do |t|
        #t.destroy unless template_ids.include?(t.template_id.to_s)
        
#        logger.info "deleteing  #{t.template_id.to_s} ---------------------- "    
        
        self.template_ids.delete(t.template_id.to_s)
      end
      self.template_ids.each do |t|
#        logger.info "building #{t} ---------------------- "    
        self.template_instances.build(:template_id => t) unless t.blank?
      end
      self.template_ids = self.template_instances.collect {|t| t.template_id}
    end

#    logger.info "self.template_ids ---------------------- "    
#    logger.info self.template_ids
#    logger.info "FINISHED update_template_instances ---------------------- "
  end

#  def load_template_instances
#    if self.template_ids.nil?
#      self.template_ids = self.template_instances.collect {|t| t.template_id} || []
#    end
#  end

end
