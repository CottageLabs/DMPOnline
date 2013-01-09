ActiveAdmin.register Organisation do
  menu :priority => 4
  
  # Limit list according to access rights
  scope_to :current_user
  
  filter :organisation_type
  
  controller do 
    authorize_resource
    helper :questions

    def show
      if params[:version] && params[:version].to_i > 0
        @organisation = Organisation.find(params[:id]).versions[params[:version].to_i - 1].try(:reify)
      end
      show!
    end

    def destroy
      @organisation = Organisation.find(params[:id])
      @organisation.destroy
      respond_to do |format| 
        if @organisation.errors[:base].present?
          flash.now[:error] = @organisation.errors[:base].to_sentence
          format.html { render action: 'show' }
        else
          flash[:notice] = I18n.t('dmp.admin.model_destroyed', model: I18n.t('activerecord.models.organisation.one'))
          format.html { redirect_to admin_organisations_url }
        end
      end
    end
  end

  sidebar :versions, partial: 'admin/shared/version', :only => :show
  member_action :history do
    @organisation = Organisation.find(params[:id])
    @page_title = I18n.t('dmp.admin.item_history', item: @organisation.full_name)
    render "admin/shared/history"
  end
  action_item :only => :history do
    link_to I18n.t('active_admin.edit_model', model: I18n.t('activerecord.models.organisation.one')), edit_admin_organisation_path(organisation)
  end
  action_item :only => :history do
    link_to I18n.t('active_admin.details', model: I18n.t('activerecord.models.organisation.one')), admin_organisation_path(organisation)
  end

  form :title => :full_name, :partial => "form"
  
  index do 
    column :logo do |organisation|
      image_tag(organisation.logo.url(:thumb), :align => :left, :border => 0) if organisation.logo.file?
    end
    column :short_name
    column :full_name
    column :branded do |organisation|
      organisation.branded ? I18n.t('dmp.boolean_yes') : I18n.t('dmp.boolean_no')
    end
    column :organisation_type
    column :url do |organisation|
      link_to organisation.url, organisation.url
    end
    column :repositories do |organisation|
      content_tag :ul do
        organisation.repositories.collect {|repository| concat(content_tag(:li, link_to(repository.name, admin_repository_path(repository))))}
      end
    end
    default_actions
  end
  
  show :title => :full_name do |organisation|
    attributes_table do
      row :short_name
      row :full_name
      row :url
      row :organisation_type
      row :dcc_edition do
        if organisation.dcc_edition.present?
          link_to organisation.dcc_edition.edition, admin_edition_path(organisation.dcc_edition)
        end
      end
      row :logo do
        if organisation.logo.file?
          image_tag(organisation.logo.url(:template), :align => :left, :border => 0)
        end
      end
      row :logo_file_size
      row :repositories do
        content_tag :ul do
          organisation.repositories.collect {|repository| concat(content_tag(:li, link_to(repository.name, admin_repository_path(repository))))}
        end
      end
      row :branded do
        organisation.branded ? I18n.t('dmp.boolean_yes') : I18n.t('dmp.boolean_no')
      end
      row :domain
      row :banner do
        if organisation.banner.file?
          image_tag(organisation.banner.url(:template), :align => :left, :border => 0)
        end
      end
      row :banner_file_size
      row :stylesheet_file_name
      row :stylesheet_file_size
      row :media_logo do
        if organisation.media_logo.file?
          image_tag(organisation.media_logo.url(:template), :align => :left, :border => 0)
        end
      end
      row :media_logo_file_size
      if shibboleth_enabled?
        row :wayfless_entity
      end
    end
    
    active_admin_comments
  end

end

