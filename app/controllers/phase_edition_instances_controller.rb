require 'rdf/turtle'

# encoding: utf-8
class PhaseEditionInstancesController < ApplicationController
  respond_to :html
  before_filter :authenticate_user!
  load_and_authorize_resource :plan
  load_and_authorize_resource :through => :plan
  helper :questions

  # GET /plans/1/layer/1/checklist
  def checklist
    @question = Question.find(params[:question_id])
  end

  # PUT /plans/1/layer/1
  # Submission of plan answers
  def update
    if params[:phase_edition_instance].present?
      if @phase_edition_instance.update_attributes(params[:phase_edition_instance])
        redirect_to complete_plan_path(@plan, tid: params[:tid].to_i, sid: params[:sid].to_i), notice: I18n.t('dmp.plan_saved')
      else
        flash[:error] = I18n.t('dmp.plan_not_saved')
        redirect_to complete_plan_path(@plan, tid: params[:tid].to_i, sid: params[:sid].to_i)
      end
    else
      flash[:error] = I18n.t('dmp.update_failed')
      redirect_to plan_path(@plan)
    end
  end

  # DELETE /plans/1/layer/1/drop_row/1
  def drop_row
    q = Question.find(params[:question_id].to_i)
    if q.is_grid?
      @phase_edition_instance.child_answers(q.id).each do |a|
        a.delete_part(params[:drop_row].to_i)
        a.save!(validate: false)
      end
    end
    
    redirect_to complete_plan_path(@plan, tid: params[:tid].to_i, sid: params[:sid].to_i, anchor: "grid_#{params[:question_id].to_i}")
  end
  
  # POST /plans/1/layer/1/add_answer?dcc_question=1
  def add_answer
    ok = false
    notice = ''
    
    valid_question = Question
                       .where(id: params[:question_id].to_i)
                       .where(edition_id: @phase_edition_instance.edition.id)
                       .first!
                       
    valid_dcc_question = Question
                       .where(id: params[:dcc_question].to_i)
                       .where(edition_id: @phase_edition_instance.edition.dcc_edition_id.to_i)
                       .first

    if valid_question.blank? || valid_dcc_question.blank?
      flash[:error] = I18n.t('dmp.invalid_question')
    else
      answer = Answer.find_or_initialize_by_phase_edition_instance_id_and_dcc_question_id(@phase_edition_instance.id, valid_dcc_question.id)
      if answer.new_record?
        answer.question_id = valid_question.id

        unless answer.save
          flash[:error] = I18n.t('dmp.answer_failed')
        end
      elsif answer.hidden
        answer.update_attributes(hidden: false)
      else
        flash[:error] = I18n.t('dmp.already_mapped')
      end
    end  
    
    unless request.xhr?
      redirect_to complete_plan_path(id: @phase_edition_instance.template_instance.plan_id, tid: @phase_edition_instance.template_instance.template_id, sid: valid_question.root.id)
    end
  end


  def output
    @eqs = @phase_edition_instance.report_questions
    @output_all = false
    @repository_queue = @phase_edition_instance.repository_action_queues
  end

  def output_all
    @eqs = @plan.report_questions
    @output_all = true
    @repository_queue = @plan.repository_action_queues
    
    render :output
  end

  # Changed to POST - IE apparently not happy with long URLs and plugins
  # POST /plans/1/phase_edition_instances/1/export
  def export
    if params[:doc].blank?
      redirect_to output_plan_layer_path(@plan, @phase_edition_instance)
      return
    end

    @doc = params[:doc]
    
    pos = @doc[:position] || {}
    unless pos.is_a?(HashWithIndifferentAccess) 
      pos = {}
    end
    unless @doc[:selection].is_a?(Array)
      @doc[:selection] = []
    end
    @doc[:selection].sort!{ |a, b| pos[a.to_s].to_i <=> pos[b.to_s].to_i }
    @doc[:selection].collect!(&:to_i)
    
    if @doc[:layout] != 'columned'
      @doc[:layout] = 'full'
    end
    if @doc[:orientation] != 'portrait'
      @doc[:orientation] = 'landscape'
      @doc[:width] = 120
    else
      @doc[:width] = 80
    end
    if @doc[:font_size].to_f > 0 && @doc[:font_size].to_f < 40 
      @doc[:font_size] = @doc[:font_size].to_f
    else
      @doc[:font_size] = 10
    end
    if @doc[:font_style] != 'serif'
      @doc[:font_style] = 'sans-serif'
    end
    @doc[:page_signatures_count] = @doc[:page_signatures_count].to_i
    if @doc[:page_signatures_count] < 1
      @doc[:page_signatures] = false
    end
    unless @doc[:page_signatures]
      @doc[:page_signatures_count] = 0
    end
    unless @doc[:page_footer]
      @doc[:page_footer_text] = ''
    end
    @doc[:page_footer_text].force_encoding('UTF-8')
    unless @doc[:page_header]
      @doc[:page_header_text] = ''
    end
    @doc[:page_header_text].force_encoding('UTF-8')
    
    @doc[:filename] = "#{@plan.project.parameterize}.#{params[:format]}"
    @doc[:format] = params[:format]
    
    unless @doc[:output_all].blank?
      @pei = @plan
    else
      @pei = @phase_edition_instance
    end
    
    if @doc[:deposit].present?
      if @plan.repository.present?
        files = []

        @plan.repository.filetypes_list.each do |format|
          logger.info "Deposit generating #{format}"
          filename = "#{@plan.project.parameterize}.#{format}"
          binary = %w(pdf docx xlsx).include?(format)
          data = export_rendering(format.to_sym)
          if %w(docx xlsx).include?(format)
            data = open(data, "rb") {|io| io.read }
          end
          
          files << {filename: filename, binary: binary, data: data}
        end
          
        # Do an EXPORT to the Edit-Media URI if there is already (or will be an entry) in the repository.
        # Otherwise, do a CREATE to Col-URI.
        if @plan.repository_entry_edit_uri.present? || @plan.current_repository_actions.try(:has_deposited_metadata?)
          # replace
          RepositoryActionQueue.enqueue(:replace_media, @plan, @doc[:output_all].blank? ? @phase_edition_instance : nil, current_user, files)
        else
          # create
          RepositoryActionQueue.enqueue(:create_metadata_media, @plan, @doc[:output_all].blank? ? @phase_edition_instance : nil, current_user, files)
        end
        # If we are depositing from a plan for the first time but it has already been locked, ensure it is finalised 
        if @plan.locked
          RepositoryActionQueue.enqueue(:finalise, @plan, nil, current_user)
        end
      end
      
      # Redirect to output selection screen
      self.formats = [:html]
      if @doc[:output_all].blank?
        url = output_plan_layer_path(@plan, @phase_edition_instance)
      else
        url = output_all_plan_layer_path(@plan, @phase_edition_instance)
      end
      redirect_to url, notice: I18n.t('repository.notify.deposit_queued')
      return

    elsif @doc[:inline].present?
      response.headers['Content-Disposition'] = 'inline; filename=' + @doc[:filename]
    elsif @doc[:attach].present?
      response.headers['Content-Disposition'] = 'attachment; filename=' + @doc[:filename]
    end
   
    respond_to do |format|
      Rails.application.config.export_formats.each do |type|
        format.send(type) { self.response_body = export_rendering(type) }
      end
    end
    
  end



  private
  
  def filter_quotes(value)
    value.gsub(/\"/,"\\\"")
  end
  
  
  # Requires @doc to be populated!
  def export_rendering(format)
    self.formats = [format.to_sym]
    template = (@doc[:layout] == 'full') ? 'export' : 'export_col'

    case format.to_sym

    # Formats with different templates for columned and full-width layouts
    when :html, :rtf
      render_to_string template.to_sym, layout: false

    # Formats with just the one view template
    when :txt, :xml, :csv
      render_to_string :export, layout: false

    when :pdf
      @doc[:page_footer] = false
      @doc[:page_header] = false
      render_to_string pdf: @doc[:filename],
          template: "phase_edition_instances/#{template}.html",
          margin: {:top => '1.7cm'},
          orientation: @doc[:orientation], 
          default_header: false,
          header: {right: '[page]/[topage]', left: filter_quotes(@doc[:page_header_text]), spacing: 3, line: true},
          footer: {center: filter_quotes(@doc[:page_footer_text]), spacing: 1.2, line: true}       

    # Special cases for xlsx and docx where a send_file is used rather than response_body
    when :xlsx
      xlsx = Tempfile.new("dmp")
      xlsx.close
      newpath = "#{xlsx.path}.xlsx"
      newpath.gsub!(/^.*:/, '')
      File.rename(xlsx.path, newpath)
      @doc[:tmpfile] = newpath
      render_to_string :export, layout: false
      if @doc[:deposit].present?
        newpath 
      else
        send_file newpath, :type => :xlsx, :filename => @doc[:filename]
      end

    when :docx
      xml_data = render_to_string 'export.xml'
      docx = Tempfile.new("dmp")
      docx.close
      media_logo = current_organisation.media_logo.file? ? current_organisation.media_logo.path : ''
      OfficeOpenXML.transform(xml_data, docx.path, @doc[:layout], media_logo)
      if @doc[:deposit].present?
        docx.path 
      else
        send_file docx.path, :type => :docx, :filename => @doc[:filename]
      end
      
    #Turtle RDF Metadata
    when :ttl
#      output = RDF::Writer.for(:ntriples).buffer do |writer|
#        writer << RDF::Graph.new do |graph|
#          graph << [:hello, RDF::DC.title, "Hello, world!"]
#        end
#      end
      render_to_string :export, layout: false
#      send_data output

    else
      nil
    end
  end
  
end
