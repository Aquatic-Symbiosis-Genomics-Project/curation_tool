require "./grit_jira_issue"
require "file_utils"

module CurationTool
  VERSION = "0.1.1"

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

    Dir.cd(wd) do
      cmd = "zcat -f #{fasta_gz} > original.fa"
      puts `#{cmd}`
      raise "something went wrong" unless $?.success?
    end
  end

  # make files from the preetxt agp and build a new pretext
  def build_release(y)
    id = y.sample_dot_version
    wd = y.working_dir

    Dir.cd(wd) do
      agp = Dir["#{wd}/*.agp_1"].sort_by { |file| File.info(file).modification_time }[-1]

      # create fasta
      cmd = "pretext-to-asm -a original.fa -o #{id}.fa -p #{agp}"
      puts `#{cmd}`
      raise "something went wrong with #{cmd}" unless $?.success?

      # trim contamination
      if y.decon_file.includes?(".bed")
        if y.merged
          ["hap1", "hap2"].each { |hap|
            decon_file = y.decon_file.sub("hap1", hap.downcase)
            primary_fa = "#{y.tol_id}.#{hap}.#{y.release_version}.primary.curated.fa"
            cmd = "/nfs/users/nfs_m/mh6/remove_contamination_bed -f #{primary_fa} -c #{decon_file} && mv #{primary_fa}_cleaned #{primary_fa}"
            puts `bsub -K -o /dev/null -q small -M 8G -R'select[mem>8G] rusage[mem=8G]' #{cmd}`
            raise "something went wrong with #{cmd}" unless $?.success?
          }
          # Make new pretext map for hap1.
          cmd = y.curation_pretext("#{id}.hap1.primary.curated.fa", "#{id}.hap1.curationpretext.#{Time.utc.to_s("%Y-%m-%d_%H:%M:%S")}")
          puts `#{cmd}`
          raise "something went wrong" unless $?.success?
        else
          cmd = "/nfs/users/nfs_m/mh6/remove_contamination_bed -f #{id}.primary.curated.fa -c #{y.decon_file} && mv #{id}.primary.curated.fa_cleaned #{id}.fa"
          puts `bsub -K -o /dev/null -q small -M 8G -R'select[mem>8G] rusage[mem=8G]' #{cmd}`
          raise "something went wrong with #{cmd}" unless $?.success?
          # Make new pretext map.
          cmd = y.curation_pretext("#{id}.primary.curated.fa", "#{id}.curationpretext.#{Time.utc.to_s("%Y-%m-%d_%H:%M:%S")}")
          puts `#{cmd}`
          raise "something went wrong" unless $?.success?
        end
      end
    end
  end

  # copy files into the curated directory for QC
  def copy_qc(y)
    target_dir = y.curated_dir
    wd = y.working_dir

    FileUtils.mkdir_p(target_dir)
    id = y.sample_dot_version

    Dir.cd(wd) do
      if y.merged
        ["hap1", "hap2"].each { |hap|
          FileUtils.touch("#{target_dir}/#{y.tol_id}.#{hap}.#{y.release_version}.all_haplotigs.curated.fa")
        }
        FileUtils.touch("#{target_dir}/#{y.tol_id}.hap2.#{y.release_version}.primary.chromosome.list.csv")
      end

      files = ["#{y.tol_id}.hap1.#{y.release_version}.fa",
               "#{y.tol_id}.hap2.#{y.release_version}.fa",
               "#{y.tol_id}.hap1.#{y.release_version}.chromosome.list.csv",
               "#{id}.primary.curated.fa",
               "#{id}.primary.chromosome.list.csv",
               "#{id}.additional_haplotigs.curated.fa",
               "#{id}.all_haplotigs.fa",
      ]

      files.each { |file_name|
        file = "#{wd}/#{file_name}"
        target = "#{target_dir}/#{file_name}"
        next unless File.exists?(file)
        puts "#{file} => #{target}"
        FileUtils.cp(file, target)
      }

      # copy pretext
      if y.merged
        pretext = Dir["#{wd}/#{id}.hap1.curationpretext.*/pretext_maps_processed/*normal.pretext"].sort_by { |file| File.info(file).modification_time }[-1]
        target = "#{y.pretext_dir}/#{y.tol_id}.hap1.#{y.release_version}.curated.pretext"
        puts "copying #{pretext} => #{target}"
        FileUtils.cp(pretext, target)
      else
        pretext = Dir["#{wd}/#{id}.curationpretext.*/pretext_maps_processed/*normal.pretext"].sort_by { |file| File.info(file).modification_time }[-1]
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
