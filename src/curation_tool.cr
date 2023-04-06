#!/bin/env crystal

require "option_parser"
require "./lib/CurationTool"

include CurationTool

issue = "GRIT-736"
setup = false
qc = false
tol = false
release = false
OptionParser.parse do |parser|
  parser.banner = "Usage: curation_tool --issue JIRA_ID [--setup_local | --copy_qc]"
  parser.on("-i JIRA_ID", "--issue JIRA_ID", "JIRA ID") { |i| issue = i }
  parser.on("-p", "--copy_pretext", "copy over pretext") { setup = true }
  parser.on("-w", "--setup_working_dir", "create initial curation files and directory") { tol = true }
  parser.on("-r", "--build_release") { release = true }
  parser.on("-q", "--copy_qc", "copy from DIR to curation for QC") { qc = true }

  parser.on("-h", "--help", "show this help") do
    puts parser
    exit
  end

  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end

  parser.missing_option do |flag|
    STDERR.puts "ERROR: #{flag} needs an argument"
    STDERR.puts parser
    exit(1)
  end
end

y = GritJiraIssue.new(issue)

# puts y.json.to_pretty_json

if setup
  puts "copy pretext => #{Dir.current}/#{y.tol_id}"
  setup_local(y)
elsif tol
  puts "staging files for RC => #{y.working_dir}"
  setup_tol(y)
elsif release
  puts "building release files and pretext => #{y.working_dir}"
  build_release(y)
elsif qc
  puts "stage for QC => #{y.curated_dir}"
  copy_qc(y)
end
