require 'net/http'
require 'json'

load File.expand_path("../tasks/slack.rake", __FILE__)

module CapistranoDeploybot
  class Capistrano
    DEFAULT_OPTIONS = {
      username: :autodeploy,
      environments: %w(staging)
    }

    def initialize(env)
      @env = env
      @opts = DEFAULT_OPTIONS.merge(fetch(:deploybot, {}))
    end

    def run
      current_revision = fetch(:current_revision)
      previous_revision = fetch(:previous_revision)
      rails_env = fetch(:rails_env)

      return if !@opts[:environments].include?(rails_env.to_s) || current_revision == previous_revision

      payload = {
        username: @opts[:username],
        text: payload_text(current_revision, previous_revision, rails_env)
      }

      @opts[:webhooks].each do |webhook|
        post_to_webhook(payload.merge(webhook: webhook))
      end
    end

    private

    def payload_text(current_revision, previous_revision, rails_env)
      "Deployed to #{rails_env}:\n" + `git shortlog #{previous_revision}..#{current_revision}`
    end

    def post_to_webhook(payload)
      begin
        response = post_to_slack_as_webhook(payload)
      rescue => e
        backend.warn("[deploybot] Error notifying Slack!")
        backend.warn("[deploybot]   Error: #{e.inspect}")
      end

      if response && response.code !~ /^2/
        warn("[deploybot] Slack API Failure!")
        warn("[deploybot]   URI: #{response.uri}")
        warn("[deploybot]   Code: #{response.code}")
        warn("[deploybot]   Message: #{response.message}")
        warn("[deploybot]   Body: #{response.body}") if response.message != response.body && response.body !~ /<html/
      end
    end

    def post_to_slack_as_webhook(payload = {})
      params = { payload: payload.to_json }
      uri = URI(payload[:webhook])
      Net::HTTP.post_form(uri, params)
    end
  end
end
