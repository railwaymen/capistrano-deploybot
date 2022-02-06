require 'net/http'
require 'json'

load File.expand_path("../tasks/slack.rake", __FILE__)

module CapistranoDeploybot
  class Capistrano
    DEFAULT_OPTIONS = {
      username: :autodeploy,
      environments: {
        staging: {
          slack_webhooks: [],
          jira_webhooks: []
        }
      }
    }

    JIRA_TICKET_ID_REGEXP = /[A-Z]{2,}-\d+/

    def initialize(env)
      @env = env
      @opts = DEFAULT_OPTIONS.merge(fetch(:deploybot, {}))
    end

    def run
      current_revision = fetch(:current_revision)
      previous_revision = fetch(:previous_revision)
      rails_env = fetch(:rails_env).to_sym

      return if !@opts[:environments].keys.include?(rails_env) || current_revision == previous_revision

      @opts[:environments].fetch(rails_env).fetch(:slack_webhooks).tap do |slack_webhooks|
        notify_slack(slack_webhooks, current_revision, previous_revision)
      end

      @opts[:environments].fetch(rails_env).fetch(:jira_webhooks).tap do |jira_webhooks|
        notify_jira(jira_webhooks, current_revision, previous_revision)
      end
    end

    private

    def notify_slack(webhooks, current_revision, previous_revision)
      application_name = @opts[:application_name]
      deploy_target = deploy_target(fetch(:rails_env), application_name)
      
      payload = {
        username: @opts[:username],
        text: payload_text(current_revision, previous_revision, deploy_target)
      }

      webhooks.each do |webhook|
        post_to_webhook(webhook, payload)
      end

      @env.info('[deploybot] Notified Slack webhooks.')  
    end
    
    def notify_jira(webhooks, current_revision, previous_revision)
      jira_issues = extract_jira_ids_from_commits(current_revision, previous_revision)
      return if jira_issues.empty?

      release_tag = ENV['CI_COMMIT_TAG']

      payload = {
        issues: jira_issues,
        data: { releaseVersion: release_tag }
      }
      
      webhooks.each do |webhook|
        post_to_webhook(webhook, payload)
      end
    
      message = "[deploybot] Notified JIRA webhooks with tickets: #{jira_issues.join(', ')}"
      message << "and release: #{release_tag}" if release_tag.present? 

      @env.info(message)  
    end

    def deploy_target(rails_env, application_name)
      application_name.nil? ? rails_env : "#{application_name} (#{rails_env})"
    end

    def extract_jira_ids_from_commits(current_revision, previous_revision)
      commits = `git show --pretty=format:%s -s #{previous_revision}..#{current_revision}`
      commits.split("\n").map { |s| s.scan(JIRA_TICKET_ID_REGEXP) }.flatten.uniq
    end

    def payload_text(current_revision, previous_revision, deploy_target)
      "Deployed to #{deploy_target}:\n" + `git shortlog #{previous_revision}..#{current_revision}`
    end

    def post_to_webhook(url, payload)
      begin
        response = perform_http_request(url, payload)
      rescue => e
        @env.warn("[deploybot] Error sending request to webhook #{url}")
        @env.warn("[deploybot]   Error: #{e.inspect}")
      end

      if response && response.code !~ /^2/
        @env.warn("[deploybot] Webhook API Failure!")
        @env.warn("[deploybot]   URI: #{response.uri}")
        @env.warn("[deploybot]   Code: #{response.code}")
        @env.warn("[deploybot]   Message: #{response.message}")
        @env.warn("[deploybot]   Body: #{response.body}") if response.message != response.body && response.body !~ /<html/
      end
    end

    def perform_http_request(url, payload)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
      req.body = payload.to_json
      http.request(req)
    end
  end
end
