require "test_helper"

class GithubClientTest < ActiveSupport::TestCase
  # A test subclass of GithubClient that skips sleep delays
  class FastGithubClient < GithubClient
    def sleep(_duration)
      # no-op: prevents real delays during tests
    end
  end

  # Test that initialize creates a GithubClient instance
  test "initialize creates a GithubClient instance" do
    client = GithubClient.new
    assert_instance_of GithubClient, client
  end

  # Test that repository raises AuthError on Octokit::Unauthorized
  test "repository maps Octokit::Unauthorized to AuthError" do
    client = GithubClient.new
    fake_octokit = Object.new
    fake_octokit.define_singleton_method(:repository) { |_repo| raise Octokit::Unauthorized }
    client.instance_variable_set(:@client, fake_octokit)

    assert_raises(GithubClient::AuthError) do
      client.repository
    end
  end

  # Test that repository raises RateLimitError on Octokit::TooManyRequests
  test "repository maps Octokit::TooManyRequests to RateLimitError" do
    client = GithubClient.new
    fake_octokit = Object.new
    fake_octokit.define_singleton_method(:repository) { |_repo| raise Octokit::TooManyRequests }
    client.instance_variable_set(:@client, fake_octokit)

    assert_raises(GithubClient::RateLimitError) do
      client.repository
    end
  end

  # Test that fetch_stats retries on empty response and raises StatsUnavailableError after 3 tries
  test "fetch_stats retries on empty response and raises StatsUnavailableError" do
    client = FastGithubClient.new
    call_count = 0

    assert_raises(GithubClient::StatsUnavailableError) do
      client.send(:fetch_stats) do
        call_count += 1
        []  # Always return empty to trigger retries
      end
    end

    assert_equal 3, call_count, "Expected exactly 3 retry attempts before raising"
  end

  # Test that latest_release returns nil when repo has no releases
  test "latest_release returns nil when repo has no releases" do
    client = GithubClient.new
    fake_octokit = Object.new
    fake_octokit.define_singleton_method(:latest_release) { |_repo| raise Octokit::NotFound }
    client.instance_variable_set(:@client, fake_octokit)

    result = client.latest_release
    assert_nil result
  end
end
