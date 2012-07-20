if Rails.env != 'test'
  email_settings = YAML::load(File.open("#{Rails.root.to_s}/config/email.yml"))
  ActionMailer::Base.smtp_settings = email_settings[Rails.env][:smtp_settings] unless email_settings[Rails.env].nil?
  ActionMailer::Base.default email_settings[Rails.env][:default] unless email_settings[Rails.env].nil?
end