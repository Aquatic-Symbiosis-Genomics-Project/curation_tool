#!/usr/bin/env crystal

require "option_parser"
require "./lib/curation_tool"

include CurationTool

issue = ""
fasta = ""
output = ""

OptionParser.parse do |parser|
  parser.banner = "Usage: submit_fcs --issue JIRA_ID "
  parser.on("-i JIRA_ID", "--issue JIRA_ID", "JIRA ID") { |jira_id| issue = jira_id }
  parser.on("-f FASTA", "--fasta FASTA", "input fasta") { |file| fasta = file }
  parser.on("-o OUTDIR", "--out OUTDIR", "output dir") { |file| output = file }

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

raise "input fasta file #{fasta} doesn't exist" unless File.exists?(fasta)

y = GritJiraIssue.new(issue, false)
puts <<-HERE
curationpretext.sh -profile sanger,singularity --input #{Path[fasta].expand} \
--sample #{y.sample_dot_version} \
--cram #{y.hic_read_dir} \
--longread #{y.pacbio_read_dir}/fasta \
--outdir #{output} \
--map_order length \
-resume

HERE
