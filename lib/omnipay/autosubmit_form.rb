# Builds an html page with an autosubmitted form, to handle POST redirections
module Omnipay
  class AutosubmitForm

    HEADER = <<-HEADER
<!DOCTYPE html>
<html>
  <head>
    <title>You are being redirected</title>
  </head>
  <body>
    <h1>Redirecting...</h1>
    HEADER

    FOOTER = <<-FOOTER
    <script type="text/javascript">
      document.getElementById('autosubmit-form').submit();
    </script>
  </body>
</html>
FOOTER

    def initialize(action, fields)
      @action = action
      @fields = fields.map{|name, value| {:name => name, :value => value}}
    end

    def html
      HEADER + form_html + FOOTER
    end

    def form_html
"    <form method=\"POST\" id=\"autosubmit-form\" action=\"#{@action}\">\n" + 
      @fields.map{|field|
"      <input type=\"hidden\" name=\"#{field[:name]}\" value=\"#{field[:value]}\"/>\n"
      }.join +
"    </form>\n"
    end

  end
end