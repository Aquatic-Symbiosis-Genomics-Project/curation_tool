# TODO: Write documentation for `CurationTool`

require "./GritJiraIssue"
require "file_utils"

module CurationTool
  VERSION = "0.1.0"

  def setup_tol(y)
    wd = y.working_dir
    Dir.mkdir_p(wd)

    fasta_gz = y.decon_file.sub("contamination", "decontaminated.fa.gz")
    fasta_gz = "zcat " + fasta_gz    

    #if a merged file exists
    merged_fasta = "/lustre/scratch123/tol/teams/grit/geval_pipeline/geval_runs/*/#{y.sample_version}/raw/merged.fa" # needs a glob[0]
    fasta_gz = "cat " + merged_fasta if File.exists?(merged_fasta)

    raise Exception.new("scaffolds.tpf in working #{wd} already exists") if File.exists?(wd + "/scaffolds.tpf")

    cmd = <<-HERE
cd #{wd} ;
#{fasta_gz} > original.fa ;
perl /software/grit/projects/vgp_curation_scripts/rapid_split.pl -fa original.fa ;
mv -f original.fa.tpf original.tpf ;
cp original.tpf scaffolds.tpf;
HERE
    puts `#{cmd}`
    raise "something went wrong" unless $?.success?
  end

  #shorthand to build a pretext
  def build_pretext(y,fasta,out,highres = false)
	cmd = "/software/grit/projects/vgp_curation_scripts/Pretext_HiC_pipeline.sh -i #{fasta} -s #{out} -k #{y.hic_read_dir} -d `pwd` #{highres_option}"
	puts `#{cmd}`
	raise "something went wrong" unless $?.success?
  end

  # make files from the preetxt agp and build a new pretext
  def build_release(y, highres = false)
    id = y.sample_version
    wd = y.working_dir
    highres_option = highres ? "-g" : ""

    Dir.cd(wd) do
      id = y.tol_id unless File.exists?("#{id}.pretext.agp_1")
      cmd = <<-HERE
touch #{id}.additional_haplotigs.unscrubbed.fa ;
rapid_pretext2tpf_XL.py scaffolds.tpf #{id}.pretext.agp_1 ;
HERE
      o = `#{cmd}`
      puts o
      raise "something went wrong" unless $?.success?
      File.write(wd + "/#{y.sample_version}.curation_stats", o)

      # if a HAP1 tpf exists
      if File.exists?("HAP1.tpf")
        puts `split_hap_tpf.rb rapid_prtxt.tpf`
        raise "something went wrong" unless $?.success?
 
        1.upto(4){|i|
          next unless File.exists?("HAP#{i}_shrapnel.tpf")
          cmd=<<-HERE
          cat HAP#{i}_shrapnel.tpf >> HAP#{i}.tpf`;
          rapid_join.pl -csv HAP#{i}.csv -fa original.fa -tpf HAP#{i}.tpf -out #{id}_HAP#{i}
          HERE
          puts `#{cmd}`
          raise "something went wrong" unless $?.success?
       
          build_pretext(y,id+"_HAP1.curated_primary.no_mt.unscrubbed.fa",id+"_HAP1",highres_option)
        }
        2.upto(4){|i|
          next unless File.exists?("#{id}_HAP#{i}.curated_primary.no_mt.unscrubbed.fa")
          # might need bsubbing, which could be bsub -K -M 8000 -R'select[mem>8000] rusage[mem=8000]'
          cmd=<<-HERE
          hap2_hap1_ID_mapping.sh #{id}_HAP1.curated_primary.no_mt.unscrubbed.fa #{id}_HAP#{i}.curated_primary.no_mt.unscrubbed.fa ;
          mv hap2_hap1.tsv hap#{i}_hap1.tsv ;
          update_mapping.rb -f #{id}_HAP#{i}.curated_primary.no_mt.unscrubbed.fa -t hap#{i}_hap1.tsv -c #{id}_HAP#{i}.updated_chromosome.list -n hap#{i}.remapping > #{id}_HAP#{i}.curated_primary.no_mt.unscrubbed.updated.fa ;
          build_pretext(y,id+"_HAP"+i+".curated_primary.no_mt.unscrubbed.fa",id+"_HAP"+i,highres_option) ;
          HERE
          puts `#{cmd}`
          raise "something went wrong" unless $?.success?
          build_pretext(y,id+"_HAP"+i+".curated_primary.no_mt.unscrubbed.fa",id+"_HAP"+i,highres_option)
        }

      else
	cmd = <<-HERE
	[ -s haps_rapid_prtxt_XL.tpf ] && rapid_join.pl -fa original.fa -tpf haps_rapid_prtxt_XL.tpf -out #{id} -hap ;
	rapid_join.pl -csv chrs.csv -fa original.fa -tpf rapid_prtxt_XL.tpf -out #{id} ;
	HERE
	puts `$cmd`
	raise "something went wrong" unless $?.success?
	
	# Make new pretext map.
	cmd = "/software/grit/projects/vgp_curation_scripts/Pretext_HiC_pipeline.sh -i #{id}.curated_primary.no_mt.unscrubbed.fa -s #{id} -k #{y.hic_read_dir} -d `pwd` #{highres_option}"
        build_pretext(y, id + "curated_primary.no_mt.unscxrubbed.fa", id, highres_option)
      end

      # gfasta
      cmd = <<-HERE
~mh6/AGPcorrect.py original.fa #{id}.pretext.agp_1 > corrected.agp ;
/software/grit/projects/gfastats/gfastats original.fa -a corrected.agp -o curated.fasta
HERE

      puts `#{cmd}`
      raise "something went wrong" unless $?.success?
    end
  end

  # copy files into the curated directory for QC
  def copy_qc(y)
    target_dir = y.curated_dir
    wd = y.working_dir
    input_id = y.sample_version
    FileUtils.mkdir_p(target_dir)

    Dir.cd(wd) do
      # sample_id + release_version | or from geval database
      input_id = y.tol_id unless File.exists?("#{input_id}.curated_primary.no_mt.unscrubbed.fa")

      # required files
      files = [
        "rapid_prtxt_XL.tpf",
        "haps_rapid_prtxt_XL.tpf",
        "#{input_id}.curated_primary.no_mt.unscrubbed.fa",
        "#{input_id}.inter.csv",
        "#{input_id}.chromosome.list.csv",
      ]

      # optional files
      ["#{input_id}.additional_haplotigs.unscrubbed.fa",
       "#{input_id}.curation_stats",
      ].each { |f| files << f if File.exists?(f) }

      files.each { |f|
        puts "copying #{wd}/#{f} => #{target_dir}/#{f}"
        FileUtils.cp("#{wd}/#{f}", "#{target_dir}/#{f}")
      }

      # copy pretext
      pretext = Dir["#{wd}/*/*.pretext"].sort_by { |f| File.info(f).modification_time }[-1]
      if pretext
        puts "copying #{pretext} => #{y.pretext_dir}/#{input_id}.curated.pretext"
        FileUtils.cp(pretext, "#{y.pretext_dir}/#{input_id}.curated.pretext")
      end
    end
  end

  # copy pretext
  def setup_local(y)
    wd = "#{Dir.current}/#{y.tol_id}"
    FileUtils.mkdir_p(wd)

    cmd = <<-HERE
touch #{wd}/notes;
scp #{ENV["USER"]}@tol:/nfs/team135/pretext_maps/#{y.tol_id}*.pretext #{wd}/
HERE
    puts `#{cmd}`
    raise "something went wrong" unless $?.success?
  end
end
