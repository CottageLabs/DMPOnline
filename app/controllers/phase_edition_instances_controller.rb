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
  # Checking to see whether submission of plan answers or update of the pei table
  def update
    success = @phase_edition_instance.update_attributes(params[:phase_edition_instance])
    if params[:phase_edition_instance][:answers_attributes].blank?
      if success
        redirect_to plan_path(@plan), notice: I18n.t('dmp.details_updated')
      else
        render :edit
      end
    else
      redirect_to complete_plan_path(@plan, tid: params[:tid].to_i, sid: params[:sid].to_i)
    end
  end

  # GET /plans/1/layer/1/edit
  # Edit only here for sword_edit_uri
  def edit

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
    @repository = @plan.repository
    
    @output_all = false
  end

  def output_all
    @eqs = @phase_edition_instance.template_instance.plan.report_questions
    @repository = @plan.repository
    
    @output_all = true

    render :output
  end

  # Changed to POST - IE apparently not happy with long URLs and plugins
  # POST /plans/1/phase_edition_instances/1/export
  def export
    if params[:doc].blank?
      redirect_to output_plan_layer_path(@plan, @phase_edition_instance)
      return
    end
    
    @repository = @plan.repository
    
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
    
    unless @doc[:inline].blank?
      response.headers['Content-Disposition'] = 'inline; filename=' + @doc[:filename]
    else
      response.headers['Content-Disposition'] = 'attachment; filename=' + @doc[:filename]
    end
    
    unless @doc[:output_all].blank?
      @pei = @plan
    else
      @pei = @phase_edition_instance
    end
    
    #Only deposit if the user clicked on deposit, and there is a repository setup for the plan
    unless (@doc[:deposit].blank? || @repository.nil?)

      #Generate files for export (done in controller so can use templated views)
      files = []
      
      #RDF (to be completed!)
      if @repository.filetype_rdf
        logger.info "Generating RDF file"
        files << {:filename => "metadata.rdf",
          :binary => false,
          :data => "TO BE COMPLETED"
        }
      end

      #PDF
      if @repository.filetype_pdf
        logger.info "Generating PDF file"
        files << {:filename => "#{@plan.project.parameterize}.pdf",
          :binary => true,
          :data => render_to_string(:pdf => "#{@plan.project.parameterize}.pdf",
            template: 'phase_edition_instances/export.html',
            margin: {:top => '1.7cm'},
            orientation: 'portrait', 
            default_header: false,
            header: {right: '[page]/[topage]', left: @doc[:page_header_text], spacing: 3, line: true},
            footer: {center: @doc[:page_footer_text], spacing: 1.2, line: true})
        }
      end
      
      #HTML
      if @repository.filetype_html
        logger.info "Generating HTML file"
        files << {:filename => "#{@plan.project.parameterize}.html",
          :binary => false,
          :data => render_to_string(:template=>"phase_edition_instances/export.html.haml", layout: false, :formats => [:html])
        }
      end
      
      #CSV
      if @repository.filetype_csv
        logger.info "Generating CSV file"
        files << {:filename => "#{@plan.project.parameterize}.csv",
          :binary => false,
          :data => render_to_string(:template=>"phase_edition_instances/export.csv.erb", layout: false, :formats => [:csv])
        }
      end

      #TXT
      if @repository.filetype_txt
        logger.info "Generating TXT file"
        files << {:filename => "#{@plan.project.parameterize}.txt",
          :binary => false,
          :data => render_to_string(:template=>"phase_edition_instances/export.txt.haml", layout: false, :formats => [:txt])
        }
      end
      
      #XML
      if @repository.filetype_xml
        logger.info "Generating XML file"
        files << {:filename => "#{@plan.project.parameterize}.xml",
          :binary => false,
          :data => render_to_string(:template=>"phase_edition_instances/export.xml.builder", layout: false, :formats => [:xml]) 
        }
      end
      
      #RTF
      if @repository.filetype_rtf
        logger.info "Generating RTF file"
        files << {:filename => "#{@plan.project.parameterize}.rtf",
          :binary => false,
          :data => render_to_string(:template=>"phase_edition_instances/export.rtf.erb", layout: false, :formats => [:rtf])
        }
      end
    
      #XLSX
      if @repository.filetype_xlsx
        logger.info "Generating XLSX file"
        
        xlsx = Tempfile.new("dmp_xlsx")
        xlsx.close
        newpath = "#{xlsx.path}.xlsx"
        newpath.gsub!(/^.*:/, '')
        File.rename(xlsx.path, newpath)
        @doc[:tmpfile] = newpath
        
        render_to_string(:template=>"phase_edition_instances/export.xlsx.erb", layout: false, :formats => [:xlsx])
        
        files << {:filename => "#{@plan.project.parameterize}.xlsx",
          :binary => true,
          :data => open(newpath, "rb") {|io| io.read }
        }
        
        File.delete(newpath)
      end
      
      #DOCX
      if @repository.filetype_docx
        logger.info "Generating DOCX file"
        xml_data = render_to_string(:template=>"phase_edition_instances/export.xml.builder", layout: false, :formats => [:xml])
        docx = Tempfile.new("dmp_docx")
        docx.close
        OfficeOpenXML.transform(xml_data, docx.path)
        
        files << {:filename => "#{@plan.project.parameterize}.docx",
          :binary => true,
          :data => open(docx.path, "rb") {|io| io.read }
        }
        
        docx.unlink #delete the temporary file
      end
      

      # Do an EXPORT to the Edit-Media URI if there is already (or will be an entry) in the repository.
      # Otherwise, do a CREATE to Col-URI.
      if (!@plan.repository_entry_edit_uri.blank? or RepositoryActionQueue.has_deposited_metadata?(@repository, @plan))
        #export
        RepositoryActionQueue.enqueue(RepositoryActionType.Replace_Media_id, @repository, @plan, @doc[:output_all].blank? ? @phase_edition_instance : nil, current_user, files)
      else
        #create
        RepositoryActionQueue.enqueue(RepositoryActionType.Create_Metadata_Media_id, @repository, @plan, @doc[:output_all].blank? ? @phase_edition_instance : nil, current_user, files)
      end

  
      #Redirect to export screen
      if (@doc[:output_all].blank?)
        redirect_to output_plan_layer_path(@plan, @phase_edition_instance)
      else
        puts "TEST--------------------------"
        puts output_all_plan_layer_path(@plan, @phase_edition_instance)
#        puts 1/0
        redirect_to output_all_plan_layer_path(@plan, @phase_edition_instance)
      end
      return
    end

    
    respond_to do |format|
      format.html { render :export, layout: false }
      format.rtf  { render :export, layout: false }
      format.txt  { render :export, layout: false }
      format.xml  { render :export, layout: false }
      format.csv  { render :export, layout: false }
      
      format.xlsx do
        xlsx = Tempfile.new("dmp")
        xlsx.close
        newpath = "#{xlsx.path}.xlsx"
        newpath.gsub!(/^.*:/, '')
        File.rename(xlsx.path, newpath)
        @doc[:tmpfile] = newpath
        render_to_string :export, layout: false
        send_file newpath, :type => :xlsx, :filename => @doc[:filename]
      end

      format.pdf do
        @doc[:page_footer] = false
        @doc[:page_header] = false
        render  pdf: @doc[:filename],
                template: 'phase_edition_instances/export.html',
                margin: {:top => '1.7cm'},
                orientation: @doc[:orientation], 
                default_header: false,
                header: {right: '[page]/[topage]', left: @doc[:page_header_text], spacing: 3, line: true},
                footer: {center: @doc[:page_footer_text], spacing: 1.2, line: true}       
      end

      format.docx do
        xml_data = render_to_string 'export.xml'
        docx = Tempfile.new("dmp")
        docx.close
        OfficeOpenXML.transform(xml_data, docx.path)
        send_file docx.path, :type => :docx, :filename => @doc[:filename]
      end

    end
  end
  
  
  
  
end
