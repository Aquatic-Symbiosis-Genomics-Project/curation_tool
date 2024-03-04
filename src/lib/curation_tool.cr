require "./grit_jira_issue"
require "file_utils"

module CurationTool
  VERSION = "0.1.0"

  def setup_tol(y)
    wd = y.working_dir
    Dir.mkdir_p(wd)

    fasta_gz = y.decon_file.sub(/contamination.*/, "decontaminated.fa.gz")

    raise Exception.new("scaffolds.tpf in working #{wd} already exists") if File.exists?(wd + "/scaffolds.tpf")

    cmd = <<-HERE
cd #{wd} ;
zcat #{fasta_gz} > original.fa ;
perl /software/grit/projects/vgp_curation_scripts/rapid_split.pl -fa original.fa ;
mv -f original.fa.tpf original.tpf ;
cp original.tpf scaffolds.tpf;
HERE
    puts `#{cmd}`
    raise "something went wrong" unless $?.success?
  end

  # make files from the preetxt agp and build a new pretext
  def build_release(y, highres = false)
    old_id = y.sample_version
    id = y.sample_dot_version
    wd = y.working_dir

    highres_option = highres ? "-g" : ""

    Dir.cd(wd) do
      cmd = <<-HERE
touch #{id}.additional_haplotigs.curated.fa ;
rapid_pretext2tpf_XL.py scaffolds.tpf #{old_id}*.pretext.agp_1 ;
[ -s haps_rapid_prtxt_XL.tpf ] && rapid_join.pl -fa original.fa -tpf haps_rapid_prtxt_XL.tpf -out #{id} -hap ;
rapid_join.pl -csv chrs.csv -fa original.fa -tpf rapid_prtxt_XL.tpf -out #{id} ;
HERE
      o = `#{cmd}`
      puts o
      raise "something went wrong" unless $?.success?

      File.write(wd + "/#{id}.curation_stats", o)
      primary = "#{id}.primary.curated.fa"

      # trim contamination
      if y.decon_file.includes?(".bed")
        cmd = <<-HERE
/nfs/users/nfs_m/mh6/remove_contamination_bed -f #{primary} -c #{y.decon_file}
mv  #{primary}_cleaned  #{primary}
HERE

        puts `#{cmd}`
        raise "something went wrong" unless $?.success?
      end

      # Make new pretext map.
      cmd = <<-HERE
  /software/grit/projects/vgp_curation_scripts/Pretext_HiC_pipeline.sh -i #{primary} -s #{id} -k #{y.hic_read_dir} -d `pwd` #{highres_option}
  HERE
      puts `#{cmd}`
      raise "something went wrong" unless $?.success?
    end
  end

  # copy files into the curated directory for QC
  def copy_qc(y)
    target_dir = y.curated_dir
    wd = y.working_dir
    id = y.sample_dot_version

    FileUtils.mkdir_p(target_dir)

    Dir.cd(wd) do
      # required files
      files = [
        "rapid_prtxt_XL.tpf", "haps_rapid_prtxt_XL.tpf", "#{id}.primary.curated.fa", "#{id}.inter.csv",
        "#{id}.primary.chromosome.list.csv", "#{id}.additional_haplotigs.curated.fa", "#{id}.curation_stats",
      ]

      files.each { |file|
        if File.exists?(file)
          puts "copying #{wd}/#{file} => #{target_dir}/#{file}"
          FileUtils.cp("#{wd}/#{file}", "#{target_dir}/#{file}")
        end
      }

      # copy pretext
      pretext = Dir["#{wd}/*/*.pretext"].sort_by { |file| File.info(file).modification_time }[-1]
      if pretext
        puts "copying #{pretext} => #{y.pretext_dir}/#{id}.curated.pretext"
        FileUtils.cp(pretext, "#{y.pretext_dir}/#{id}.primary.curated.pretext")
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
