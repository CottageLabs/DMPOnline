ActiveAdmin.register Question do 
  menu false
  config.clear_action_items!

  index do
    # We don't want anyone to reach this...
    controller.redirect_to admin_templates_path
  end

  sidebar :versions, partial: 'admin/shared/version', only: [:edit, :show]
  member_action :history do
    @question = Question.find(params[:id])
    @page_title = I18n.t('dmp.admin.item_history', item: ActionController::Base.helpers.strip_tags(@question.question).truncate(50))
    render "admin/shared/history"
  end
  action_item :only => :history do
    link_to I18n.t('active_admin.edit_model', model: I18n.t('activerecord.models.question.one')), edit_admin_question_path(question)
  end
  action_item :only => :history do
    link_to I18n.t('active_admin.details', model: I18n.t('activerecord.models.question.one')), admin_question_path(question)
  end
  action_item :only => :edit do
    link_to I18n.t('active_admin.delete_model', model: I18n.t('activerecord.models.question.one')), admin_question_path(question), :method => :delete, :confirm => I18n.t('dmp.admin.delete_confirm')
  end

  form :title => :question, :partial => "form"
  
  show do |question|
    attributes_table do
      row :kind do |question|
        display = translated_types.invert
        display[question.kind]
      end
      row :number_style do |question|
        display = translated_styles.invert
        display[question.number_style]
      end
      row :question do
        sanitize question.question
      end
      row :default_value
    end
    
    active_admin_comments
  end

  controller do
    authorize_resource
    helper :questions
    
    def show
      if params[:version] && params[:version].to_i > 0
        @question = Question.find(params[:id]).versions[params[:version].to_i - 1].try(:reify)
      end
      show!
    end

    def new
      @edition = Edition.find(params[:edition])
      @question = Question.new
      @question.edition_id = @edition.id
      new!
    end
    
    def create
      @edition = Edition.find(params[:question][:edition_id])
      params[:question].delete(:edition_id)
      @question = Question.new(params[:question])
      @question.edition = @edition

      respond_to do |format|
        if @question.save
          format.html { redirect_to edit_admin_edition_path(@question.edition.id), notice: t('dmp.admin.question_created') }
        else
          format.html { render action: "new" }
        end
      end
            
    end

    def update
      @question = Question.find(params[:id])
      mapping_button = /mappings_(\d+)/.match(params.keys.join(','))

      respond_to do |format|
        if @question.update_attributes(params[:question])
          format.html do
            if mapping_button.nil?
              redirect_to edit_admin_edition_path(@question.edition.id), notice: t('dmp.admin.question_updated')
            else
              redirect_to edit_admin_mapping_path(mapping_button[1]),  notice: t('dmp.admin.question_updated')
            end
          end
        else
          format.html { render action: "edit" }
        end
      end
      
    end
    

    def destroy
      @question = Question.find(params[:id])
      @edition = @question.edition_id
      @question.destroy

      respond_to do |format| 
        if @question.errors[:base].present?
          flash[:error] = @question.errors[:base].to_sentence
        else
          flash[:notice] = I18n.t('dmp.admin.model_destroyed', model: I18n.t('activerecord.models.question.one'))
        end
        format.html { redirect_to edit_admin_edition_path(@edition) }
      end
    end
        
  end

  collection_action :dcc_build, :method => :post do
    @edition = Edition.find(params[:edition])
    unless @edition.questions.empty? 
      flash[:error] = t('dmp.admin.already_has_questions')
      redirect_to edit_admin_edition_path(@edition)
      return
    end

    qs = view_context.dcc_checklist_questions(@edition)
    prev_head_top = false
    prev_head_top_q = 0
    prev_head_q = 0
    pos = 0
    qs.each do |q|
      pos += 1
      if q.is_heading? || q.depth <= 1
        prev_head_top = q.depth == 0

        tq = Question.new
        tq.edition = @edition
        if q.depth == 0
          tq.kind = 'h'
        else
          tq.kind = 'm'
          tq.parent_id = prev_head_top_q
        end
        tq.number_style = q.number_style
        tq.question = q.question
        tq.save!
        prev_head_q = tq.id
        if q.depth == 0
          prev_head_top_q = tq.id
        end
      end
      unless q.is_mapped? || q.is_heading? || q.depth == 0
        tm = Mapping.new
        tm.question_id = prev_head_q
        tm.dcc_question_id = q.id
        tm.position = pos
        tm.save!
      end
    end

    redirect_to edit_admin_edition_path(@edition)
  end

  collection_action :manage, :method => :get do
    @questions = Question.nested_set.all
  end
  
  collection_action :rebuild, :method => :post do
    id        = params[:id].to_i
    parent_id = params[:parent_id].to_i
    prev_id   = params[:prev_id].to_i
    next_id   = params[:next_id].to_i

    render :text => "Do nothing" and return if parent_id.zero? && prev_id.zero? && next_id.zero?

    collection = 'questions'
    variable = collection.singularize
    klass = variable.classify.constantize
    variable = "@#{variable}"
    variable = self.instance_variable_set(variable, klass.find(id))

    if prev_id.zero? && next_id.zero?
      variable.move_to_child_of klass.find(parent_id)
    elsif !prev_id.zero?
      variable.move_to_right_of klass.find(prev_id)
    elsif !next_id.zero?
      variable.move_to_left_of klass.find(next_id)
    end

    render(:nothing => true)

  end
end
