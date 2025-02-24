require 'octokit'
require 'open3'
require 'dotenv'

if ARGV.count != 1
  puts "Usage: script/count [ORG NAME]"
  exit 1
end

Dotenv.load

tmp_dir = File.expand_path "./tmp", File.dirname(__FILE__)
FileUtils.rm_rf tmp_dir
FileUtils.mkdir_p tmp_dir

export_dir = File.expand_path "./exports", File.dirname(__FILE__)
FileUtils.rm_rf export_dir
FileUtils.mkdir_p export_dir

# Enabling support for GitHub Enterprise
unless ENV["GITHUB_ENTERPRISE_URL"].nil?
  Octokit.configure do |c|
    c.api_endpoint = ENV["GITHUB_ENTERPRISE_URL"]
  end
end

client = Octokit::Client.new access_token: ENV["GITHUB_TOKEN"]
client.auto_paginate = true

repos = client.organization_repositories(ARGV[0].strip, type: 'sources').reject(&:archived)
repo_count = repos.count
puts "Found #{repos.count} repos. Exporting..."

reports = []
repos.each_with_index do |repo, index|
  puts "(#{index} / #{repo_count}) - Exporting #{repo.name}..."

  destination = File.expand_path repo.name, tmp_dir
  report_file = File.expand_path "#{repo.name}.txt", tmp_dir

  clone_url = repo.clone_url
  clone_url = clone_url.sub "//", "//#{ENV["GITHUB_TOKEN"]}:x-oauth-basic@" if ENV["GITHUB_TOKEN"]
  output, status = Open3.capture2e "git", "clone", "--depth", "1", "--quiet", clone_url, destination
  next unless status.exitstatus == 0

  # Remove the git info
  FileUtils.rm_rf "#{destination}/.git"

  `tar -zcvf exports/#{repo.name}.tar.gz -C #{tmp_dir} #{repo.name}`
end

puts "Done..."
