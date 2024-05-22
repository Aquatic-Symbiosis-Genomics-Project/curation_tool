require "./grit_jira_issue"
require "file_utils"

module CurationTool
  VERSION = "0.1.0"

  def setup_tol(y)
    wd = y.working_dir
    Dir.mkdir_p(wd)

    fasta_gz = y.decon_file.sub(/contamination.*/, "decontaminated.fa.gz")

    if y.merged
      if y.yaml.as_h.has_key?("hap1")
        fasta_gz = y.yaml["hap1"].as_s + " " + y.yaml["hap2"].as_s
      elsif y.yaml.as_h.has_key?("maternal")
        fasta_gz = y.yaml["maternal"].as_s + " " + y.yaml["paternal"].as_s
      else
        fasta_gz = y.yaml["primary"].as_s + " " + y.yaml["haplotigs"].as_s
      end
      fasta_gz = fasta_gz.gsub(".fa.gz", ".decontaminated.fa.gz")
    end

    raise Exception.new("scaffolds.tpf in working #{wd} already exists") if File.exists?(wd + "/scaffolds.tpf")

    cmd = <<-HERE
cd #{wd} ;
zcat -f #{fasta_gz} > original.fa ;
rapid_split.pl -fa original.fa ;
mv -f original.fa.tpf original.tpf ;
cp original.tpf scaffolds.tpf;
HERE
    puts `#{cmd}`
    raise "something went wrong" unless $?.success?
  end

  # make files from the preetxt agp and build a new pretext
  def build_release(y)
    id = y.sample_dot_version
    wd = y.working_dir

    Dir.cd(wd) do
      cmd = "pretext-to-tpf -a original.tpf -p *.agp_1 -o #{id}.tpf -w -f"
      o = `#{cmd}`
      puts o
      raise "something went wrong" unless $?.success?

      bsub = "bsub -G grit-grp -K -M 16G -R'select[meme>16G] rusage[mem=16G]'"
      # create fasta
      if y.merged
        ["HAP1", "HAP2"].each { |label|
          cmd = "#{bsub} rapid_join.pl -tpf *#{label}.tpf -csv chrs_#{label}.csv -o #{id}.#{label} -f original.fa"
          o = `#{cmd}`
          puts o
          raise "something went wrong" unless $?.success?
        }
      else
        cmd = <<-HERE
touch #{id}.additional_haplotigs.curated.fa ;
#{bsub} rapid_join.pl -tpf #{id}.tpf -csv chrs.csv -o #{id} -f original.fa ;
[ -s #{id}_Haplotigs.tpf ] && #{bsub} rapid_join.pl -tpf #{id}_Haplotigs.tpf -o #{id} -f original.fa -hap ;
HERE
        o = `#{cmd}`
        puts o
        raise "something went wrong" unless $?.success?
      end

      # Make new pretext map.
      cmd = <<-HERE
for f in *primary.curated.fa ;
do
  Pretext_HiC_pipeline.sh -i $f -s $f -d .  -k #{y.hic_read_dir} &
done
HERE
      puts `#{cmd}`
      raise "something went wrong" unless $?.success?
    end
  end

  # copy files into the curated directory for QC
  def copy_qc(y)
    target_dir = y.curated_dir
    wd = y.working_dir

    FileUtils.mkdir_p(target_dir)

    Dir.cd(wd) do
      files = Dir["*.primary.curated.fa", "*.primary.chromosome.list.csv", "*_haplotigs.curated.fa"]
      files.each { |file|
        new_file = file
        if y.merged
          /\S+_(\w+)(\.primary.*)/.match(file)
          new_file = "#{y.tol_id}.#{$1.to_s.downcase}.#{y.release_version}.#{$2}"
        end
        target = "#{target_dir}/#{new_file}"
        puts "copying #{wd}/#{file} => #{target}"
        FileUtils.cp("#{wd}/#{file}", target)
      }

      # copy pretext
      if y.merged
        ["HAP1", "HAP2"].each { |hap|
          pretext = Dir["#{wd}/*/*#{hap}*.pretext"].sort_by { |file| File.info(file).modification_time }[-1]
          target = "#{y.pretext_dir}/#{y.tol_id}.#{hap}.#{y.release_version}.curated.pretext"
          puts "copying #{pretext} => #{target}"
          FileUtils.cp(pretext, target)
        }
      else
        pretext = Dir["#{wd}/*/*.pretext"].sort_by { |file| File.info(file).modification_time }[-1]
        target = "#{y.pretext_dir}/#{y.sample_dot_version}.curated.pretext"
        puts "copying #{pretext} => #{target}"
        FileUtils.cp(pretext, target)
      end
    end
  end

  # copy pretext
  def setup_local(y)
    wd = "#{Dir.current}/#{y.tol_id}"
    FileUtils.mkdir_p(wd)

    cmd = <<-HERE
touch #{wd}/notes;
scp #{ENV["USER"]}@tol:/nfs/treeoflife-01/teams/grit/data/pretext_maps/#{y.tol_id}*.pretext #{wd}/
HERE
    puts `#{cmd}`
    raise "something went wrong" unless $?.success?
  end
end
