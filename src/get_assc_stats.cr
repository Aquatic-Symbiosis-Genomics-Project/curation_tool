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
  r = Hash(String, Float64).new
  fp = GzipReader.new(f)
  fx = FastxReader.new(fp)
  fx.each { |e|
    l[e.name] = e.seq.size
    g[e.name] = e.seq.count("gcGC")/e.seq.size
    r[e.name] = e.seq.count("[a-z]")/e.seq.size
  }
  return(l, g, r)
end

def av(l : Array(Int32 | Float64))
  items = l.size
  if l.is_a?(Array(Float64))
    total = 0_f64
    l.each { |i| total += i.to_f }
    total/items
  else
    total = 0_u64
    l.each { |i| total += i }
    total/items
  end
end

def get_ave(h, l : Array(String))
  av(l.map { |k| h[k] })
end

puts ["tolID", "fasta file", "average gc", "average length", "average repeat",
      "true positives", "average gc tp", "average len tp", "average repeat tp",
      "false positives", "average gc fp", "average len fp", "average repeat fp",
      "false negatives", "average gc fn", "average len fn", "average repeat fn"].join("\t")

ARGV.each { |jira_id|
  y = StatIssue.new(jira_id)

  Dir.glob("#{y.decon_dir}/*.contamination").each { |c|
    contamination_ids = parse_decon_file(c)
    bed_file = "#{c}.bed"
    next unless File.exists?(bed_file)
    bed_ids = parse_bed_file(bed_file)

    fasta_file = c.gsub(".contamination", ".fa")
    next unless File.exists?(fasta_file + ".gz")

    masked_file = fasta_file + ".masked.gz"
    unless File.exists?(masked_file)
      `zcat #{fasta_file}.gz | /software/grit/bin/ncbi-blast-2.10.0+/bin/dustmasker -outfmt fasta | gzip -9 -c > #{masked_file}`
      raise "couldn't create #{masked_file}" unless $?.success?
    end

    ln, gc, rep = length_and_gc(masked_file)
    true_positives = contamination_ids & bed_ids
    false_positives = bed_ids - contamination_ids
    false_negatives = contamination_ids - bed_ids

    columns = [y.tol_id, File.basename(c), av(gc.values), av(ln.values)]

    [true_positives, false_positives, false_negatives].each { |s|
      columns << s.size
      columns << get_ave(gc, s)
      columns << get_ave(ln, s)
      columns << get_ave(rep, s)
    }
    puts columns.join("\t")
  }
}
