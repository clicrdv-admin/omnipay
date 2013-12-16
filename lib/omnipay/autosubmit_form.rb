# Builds an html page with an autosubmitted form, to handle POST redirections
module Omnipay
  class AutosubmitForm

    HEADER = <<-HEADER
<!DOCTYPE html>
<html>
  <head>
    <script type="text/javascript">
      window.onload=function(){
        document.getElementById('autosubmit-form').submit();
      }
    </script>
  </head>

  <body>
    <h1>Redirecting...</h1>
    HEADER

    FOOTER = <<-FOOTER
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