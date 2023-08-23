#!/bin/env crystal

require "./lib/GritJiraIssue"
require "klib"

include Klib

class StatIssue < GritJiraIssue
  def decon_dir
    Path[self.decon_file].parent.to_s
  end
end

def parse_decon_file(f)
  i = [] of String
  File.each_line(f) do |line|
    if /^REMOVE\s+(\S+)/i.match(line)
      i << $1
    end
  end
  i
end

def parse_bed_file(f)
  i = [] of String
  File.each_line(f) do |line|
    if /^(\S+)\s.*REMOVE/i.match(line)
      i << $1
    end
  end
  i
end

# length_and_gc_from_fasta
def length_and_gc(f)
  l = Hash(String, Int32).new
  g = Hash(String, Float64).new
  fp = GzipReader.new(f)
  fx = FastxReader.new(fp)
  fx.each { |e|
    l[e.name] = e.seq.size
    g[e.name] = e.seq.size/e.seq.count("gcGC")
  }
  return(l, g)
end

def av(l : Array(Int32|Float64) )
  items = l.size
  total = 0
  l.each { |i| total += i }
  total/items
end

def get_ave(h, l : Array(String))
  av(l.map{|k| h[k] })
end

ARGV.each { |jira_id|
  y = StatIssue.new(jira_id)

  Dir.glob("#{y.decon_dir}/*.contamination").each { |c|
    contamination_ids = parse_decon_file(c)
    bed_file = "#{c}.bed"
    next unless File.exists?(bed_file)
    bed_ids = parse_bed_file(bed_file)

    # fasta would be s/.contamination/.fa.gz/
    fasta_file = bed_file.gsub(".contamination", ".fa.gz")
    next unless File.exists?(fasta_file)
    l, g = length_and_gc(fasta_file)
    true_positives = contamination_ids & bed_ids
    false_positives = bed_ids - contamination_ids
    false_negatives = contamination_ids - bed_ids

    puts "#{y.tol_id} #{c} #{true_positives.size} #{get_ave(g, true_positives)} #{get_ave(l, true_positives)} #{false_positives.size} #{get_ave(g, false_positives)} #{get_ave(l, false_positives)} #{false_negatives.size} #{get_ave(g, false_negatives)} #{get_ave(l, false_negatives)}"
  }
}
