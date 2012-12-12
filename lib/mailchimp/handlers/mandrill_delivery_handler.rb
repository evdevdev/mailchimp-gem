module Mailchimp
  class MandrillDeliveryHandler
    attr_accessor :settings

    def initialize(options = {})
      self.settings = {:track_opens => true, :track_clicks => true, :from_name => 'Mandrill Email Delivery Handler'}.merge(options)
    end

    def deliver!(message)

      message_payload = {
        :track_opens => settings[:track_opens],
        :track_clicks => settings[:track_clicks],
        :message => {
          :subject => message.subject,
          :from_name => settings[:from_name],
          :from_email => message.from.first,
          :to => ensure_mandrill_compatible_mail_format(message.to)
        }
      }

      [:html, :text].each do |format|
        content = get_content_for(message, format)
        message_payload[:message][format] = content if content
      end

      message_payload[:tags] = settings[:tags] if settings[:tags]

      #payload parameters that take an array but that come in as a string
      ["tags", 'google_analytics_domains', 'google_analytics_campaign'].each do |parameter|
        next if message[parameter].blank?
        message_payload[parameter] = message[parameter].split(",")
      end

      message_payload[:tags] = message["X-MC-Tags"] unless message["X-MC-Tags"].blank?
      message_payload[:google_analytics_domains] = message['X-MC-GoogleAnalytics'] unless message['X-MC-GoogleAnalytics'].blank?
      message_payload[:google_analytics_campaign] = message['X-MC-GoogleAnalyticsCampaign'] unless message['X-MC-GoogleAnalyticsCampaign'].blank?

      api_key = message.header['api-key'].blank? ? settings[:api_key] : message.header['api-key']

      Mailchimp::Mandrill.new(api_key).messages_send(message_payload)
    end

    private

    def get_content_for(message, format)
      mime_types = {
        :html => "text/html",
        :text => "text/plain"
      }

      content = message.send(:"#{format.to_s}_part")
      content ||= message.body if message.mime_type == mime_types[format]
      content
    end

    def ensure_mandrill_compatible_mail_format(to)
      #to: recipients can be either "someone@somewhere.net" or "That Guy <someone@somewhere.net>"

      to.map do |recipient|
        if email_index = recipient =~ /<.*>$/
          {
            :name => recipient[0, email_index].strip,
            :email => recipient[email_index + 1, recipient.length].chop #remove leading and trailing <,>
          }
        else
          {email: recipient}
        end
       # recipient.is_a?(String) ? {:email => recipient} : recipient
      end
    end

  end
end

if defined?(ActionMailer)
  ActionMailer::Base.add_delivery_method(:mailchimp_mandrill, Mailchimp::MandrillDeliveryHandler)
end

