require "rails_helper"

RSpec.describe "Admin return_to safety", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "keeps query-string internal paths for recurring job detail and request actions" do
    sign_in_as(admin_user)
    schedule = create_schedule!
    return_to = admin_recurring_job_schedules_path(status: "failed", enabled: "false", page: 2)
    allow(RecurringJobDispatcherJob).to receive(:perform_later)

    get admin_recurring_job_schedule_path(schedule, return_to:)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(a[href="#{return_to}"]))).to be_present

    post request_run_admin_recurring_job_schedule_path(schedule, return_to:)

    expect(response).to redirect_to(admin_recurring_job_schedule_path(schedule, return_to:))
    expect(RecurringJobDispatcherJob).to have_received(:perform_later)
  end

  it "falls back for unsafe recurring job return_to values" do
    sign_in_as(admin_user)
    schedule = create_schedule!
    allow(RecurringJobDispatcherJob).to receive(:perform_later)

    unsafe_return_to_values.each_value do |return_to|
      get admin_recurring_job_schedule_path(schedule, return_to:)

      expect(response).to have_http_status(:ok)
      expect(parsed_html.at_css(%(a[href="#{admin_recurring_job_schedules_path}"]))).to be_present

      post request_run_admin_recurring_job_schedule_path(schedule, return_to:)

      expect(response).to redirect_to(admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path))
    end
  end

  it "keeps filtered list paths for generated file run detail and retry actions" do
    sign_in_as(admin_user)
    run = create_generated_file_run!(status: :failed)
    return_to = admin_generated_file_runs_path(status: "failed", page: 2, per_page: 25)
    allow(GeneratedFileJob).to receive(:perform_later)

    get admin_generated_file_run_path(run.public_id, return_to:)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(a[href="#{return_to}"]))).to be_present

    post retry_run_admin_generated_file_run_path(run.public_id, return_to:)

    expect(response).to redirect_to(admin_generated_file_run_path(run.public_id, return_to:))
    expect(GeneratedFileJob).to have_received(:perform_later)
  end

  it "falls back for unsafe generated file run return_to values" do
    sign_in_as(admin_user)
    run = create_generated_file_run!(status: :failed)
    allow(GeneratedFileJob).to receive(:perform_later)

    unsafe_return_to_values.each_value do |return_to|
      get admin_generated_file_run_path(run.public_id, return_to:)

      expect(response).to have_http_status(:ok)
      expect(parsed_html.at_css(%(a[href="#{admin_generated_file_runs_path}"]))).to be_present

      post retry_run_admin_generated_file_run_path(run.public_id, return_to:)

      expect(response).to redirect_to(admin_generated_file_run_path(run.public_id, return_to: admin_generated_file_runs_path))
    end
  end

  def unsafe_return_to_values
    {
      blank: "",
      protocol_relative: "//example.com/admin",
      http_url: "https://example.com/admin",
      non_http_scheme: "javascript:alert(1)",
      fragment_only: "#runs",
      control_character: "/admin/generated_file_runs\nhttps://example.com"
    }
  end

  def create_schedule!(attributes = {})
    defaults = {
      job_key: "sample_job",
      job_class: "SampleJob",
      queue_name: "default",
      interval_seconds: 1.hour.to_i,
      next_run_at: 1.hour.from_now,
      enabled: true,
      allow_overlap: false,
      args_json: []
    }

    RecurringJobSchedule.create!(defaults.merge(attributes))
  end

  def create_generated_file_run!(attributes = {})
    defaults = {
      job_id: "sample_job",
      generator: "sample_generator",
      output_writer: "filesystem",
      status: :completed,
      event_source: "spec",
      source_paths: ["source.yml"],
      changed_files: ["source.yml"],
      generated_paths: ["generated.md"],
      metadata: {},
      started_at: 1.minute.ago,
      finished_at: Time.current
    }

    GeneratedFileRun.create!(defaults.merge(attributes))
  end
end
