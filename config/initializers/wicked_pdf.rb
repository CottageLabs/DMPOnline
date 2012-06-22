WickedPdf.config = {
  layout: false,
  show_as_html: false,
  page_size: 'A4',
}

if !!RUBY_PLATFORM['mingw32']
  WickedPdf.config[:exe_path] = '/progra~1/wkhtmltopdf/wkhtmltopdf.exe'
else
  WickedPdf.config[:wkhtmltopdf] = '/Applications/wkhtmltopdf.app/Contents/MacOS/wkhtmltopdf'  
end