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
  #after_save :update_template_instances     #MW FIX
  #after_initialize :load_template_instances
  
  before_validation :update_template_instances
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
  
  def has_deposited_media?(phase_edition_instance = nil)
    RepositoryActionQueue.has_deposited_media?(repository, self, phase_edition_instance) ? 1 : 0 #Easier to parse 1 or 0 in Javascript
  end
  
  
  def repository_status(phase_edition_instance = nil)
    entry = RepositoryActionQueue.latest_entry_by_phase(repository, self, phase_edition_instance)
    if (phase_edition_instance)
      phase = phase_edition_instance.edition.phase.phase
    else
      phase = "all phases"
    end
      
    if (entry)
      "#{entry.repository_action_type.name}: #{entry.repository_action_status.name} (#{phase})"
    else
      I18n.t("repository.label.no_repository_queue_record") + " (#{phase})"
    end
  end
  

  
  def template_ids
    puts "IN template_ids --------------"
    puts "BEFORE1 @template_ids = #{@template_ids}"
    @template_ids ||= template_instances.collect {|template_instance| template_instance.template_id.to_s}
    puts "AFTER1 @template_ids = #{@template_ids}"

    puts "FINISHED template_ids --------------"
    puts " "
    @template_ids
  end
  
  def template_ids=value
    puts "IN template_ids=VALUE --------------"
    puts "BEFORE2 @template_ids = #{@template_ids}"
    
    @template_ids = value
    puts "AFTER2 @template_ids = #{@template_ids}"

    puts "FINISHED template_ids=VALUE --------------"
    puts " "
    
    @template_ids
  end
  
  

  
  protected
  
  def load_template_instances
    puts "---E0 (load_template_instances) @template_ids = #{@template_ids}"
    
    
     if @template_ids.nil?
       @template_ids = template_instances.collect {|template_instance| template_instance.template_id.to_s} || []
       
       puts "---E1 (load_template_instances) @template_ids = #{@template_ids}"
     end
     
     puts "---E2 (load_template_instances) @template_ids = #{@template_ids}"


    @template_ids
  end

  def update_template_instances

    puts "---IN update_template_instances MW"

    puts "---A template_ids = #{template_ids}"

      #For each template_instance which has an entry in template_ids, delete the record in template_ids
      template_instances.each do |template_instance|
        template_ids.delete(template_instance.template_id.to_s)
      end

      puts "---B template_ids = #{template_ids}"

      #for each entry in template_ids, create a new templaet instance
      template_ids.each do |template_id|
        template_instances.build(:template_id => template_id.to_i) unless template_id.blank?
      end

      puts "---C template_ids = #{template_ids}"
      
      
      #now resynchronise template_ids
      load_template_instances
      
      puts "---D template_ids = #{template_ids}"
            
#      template_ids = template_instances.collect {|template_instance| template_instance.template_id}

  end


end
