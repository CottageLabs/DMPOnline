module ApplicationHelper
  def title(page_title)
    content_for(:title) { page_title }
  end
  
  def slug_link(page)
    page.target_url.blank? ? pages_slug_path(:slug => page.slug) : page.target_url
  end

  def error_notices(error_text)
    content_for(:error_notices) { error_text }
  end
  
  def organisation_stylesheet
    if current_organisation.blank? || !current_organisation.branded || !current_organisation.stylesheet.file?
      stylesheet_link_tag 'application'
    else
      stylesheet_link_tag current_organisation.stylesheet.url
    end
  end
  
  def organisation_logo
    if current_organisation.present? && current_organisation.banner.file?
      image_tag(current_organisation.banner.url(:home), :alt => t('dmp.title') + ' - ' + t('dmp.strapline'))
    elsif current_organisation.present? && current_organisation.logo.file?
      image_tag(current_organisation.logo.url(:home), :alt => t('dmp.title') + ' - ' + t('dmp.strapline'))
    else
      image_tag('dmp_logo.png', :alt => t('dmp.title') + ' - ' + t('dmp.strapline'))
    end
  end
  
  def no_rss_feed
    base = controller_path.split('/').first
    base == 'admin' || base == 'devise'
  end

  def ajax_preloader
    controller.render_to_string partial: "layouts/preloader"
  end
  
  def plan_display(plan, attribute, date_format = :long, show_none = false)
    if plan.respond_to?(attribute) && plan.send(attribute).blank?
      if show_none
        content_tag :span, t('dmp.admin.none'), :class => 'empty'
      else 
        ""
      end
    else
      case attribute
      when :budget
        if plan.currency.nil? 
          if show_none
            content_tag :span, t('dmp.admin.none'), :class => 'empty'
          else 
            ""
          end
        else 
          number_to_currency(plan.budget, unit: plan.currency.symbol).force_encoding('UTF-8')
        end
      when :created_at, :updated_at, :start_date, :end_date
        l plan.send(attribute), format: date_format
      when :repository
        r = plan.send(attribute)
        "#{r.name} (#{r.organisation.full_name})".force_encoding('UTF-8')
      when :source_plan
        plan.send(attribute).project.force_encoding('UTF-8')
      when :owner
        plan.user.email.force_encoding('UTF-8')
      else
        plan.send(attribute).force_encoding('UTF-8')
      end
    end
  end
  
  def bp_format(content)
    simple_format(content.strip, {}, sanitize: true)
  end

  # User categories 
  def translated_categories
     User::CATEGORIES.inject({}) do |hash, k|  
       hash.merge!(I18n.t("dmp.categories.#{k}") => k)
     end
  end

  def export_formats_collection
    opts = []
    Rails.application.config.export_formats.each do |filetype|
      opts << [I18n.t("dmp.formats.#{filetype.to_s}"), filetype.to_s]
    end
    opts
  end
  
  def export_formats_option_list  
    options_for_select(export_formats_collection).html_safe
  end

  def metadata_option_available?
    Rails.application.config.export_formats.include?(:ttl)  # or :rdf ????  TO CHECK
  end
end
