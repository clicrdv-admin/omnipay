module Omnipay

  # This class is responsible for generating an html page which will redirect its visitor to an arbitrary url,
  # with arbitrary POST parameters in the request body.
  # 
  # It does so by including an hidden form in the page, and submitting it via javascript on page load.
  # 
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


    # Initializes the form with its action, and its inputs name/value pairs
    # 
    # @param action [String] The url the form must be submitted to. Will be the value of its <action> attribute
    # @param fields [Hash] The key/value pairs of parameters to be sent as POST to the action. Will be a set of hidden <inputs> in the form.
    #
    # @return [AutosubmitForm]
    def initialize(action, fields)
      @action = action
      @fields = fields.map{|name, value| {:name => name, :value => value}}
    end


    # Returns the full html page
    # @return [String]
    def html
      HEADER + form_html + FOOTER
    end


    private

    def form_html
"    <form method=\"POST\" id=\"autosubmit-form\" action=\"#{@action}\">\n" + 
      @fields.map{|field|
"      <input type=\"hidden\" name=\"#{field[:name]}\" value=\"#{field[:value]}\"/>\n"
      }.join +
"    </form>\n"
    end

  end
end