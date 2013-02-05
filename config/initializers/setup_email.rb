email_config_file = "#{Rails.root.to_s}/config/email.yml"

if Rails.env != 'test' && File.exists?(email_config_file)
  email_settings = YAML::load(File.open(email_config_file))
  ActionMailer::Base.smtp_settings = email_settings[Rails.env][:smtp_settings] unless email_settings[Rails.env].nil?
  ActionMailer::Base.default email_settings[Rails.env][:default] unless email_settings[Rails.env].nil?
end