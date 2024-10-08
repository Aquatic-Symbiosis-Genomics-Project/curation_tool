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
      agp = Dir["#{wd}/*.agp_1"].sort_by { |file| File.info(file).modification_time }[-1]

      cmd = "pretext-to-tpf -a original.tpf -p #{agp} -o #{id}.tpf -w -f"
      puts `#{cmd}`
      raise "something went wrong" unless $?.success?

      bsub = "bsub -K -M 16G -R'select[mem>16G] rusage[mem=16G]' -o /dev/null"
      # create fasta
      if y.merged
        cmd = "#{bsub} multi_join.py --tpf #{id}_HAP1.tpf --tpf2 #{id}_HAP2.tpf --csv chrs_HAP1.csv --csv2 chrs_HAP2.csv --out #{y.tol_id} --fasta original.fa"
        puts `#{cmd}`
        raise "something went wrong with #{cmd}" unless $?.success?

        ["hap1", "hap2"].each { |label|
          if y.decon_file.includes?(".bed")
            decon_file = y.decon_file.sub("hap1", label.downcase)
            primary_fa = "#{y.tol_id}.#{label}.1.primary.curated.fa"
            cmd = "/nfs/users/nfs_m/mh6/remove_contamination_bed -f #{primary_fa} -c #{decon_file} && mv  #{primary_fa}_cleaned #{primary_fa}"
            puts `#{cmd}`
            raise "something went wrong with #{cmd}" unless $?.success?
          end
        }
      else
        cmd = "touch #{id}.additional_haplotigs.curated.fa && touch #{id}_Haplotigs.tpf"
        puts `#{cmd}`
        cmd = "#{bsub} multi_join.py --tpf #{id}.tpf --csv chrs.csv --out #{y.tol_id} --fasta original.fa --hap #{id}_Haplotigs.tpf"
        puts `#{cmd}`
        raise "something went wrong with #{cmd}" unless $?.success?

        # trim contamination
        if y.decon_file.includes?(".bed")
          primary_fa = "#{id}.primary.curated.fa"
          cmd = "/nfs/users/nfs_m/mh6/remove_contamination_bed -f #{y.tol_id}.1.primary.curated.fa -c #{y.decon_file} && mv  #{primary_fa}_cleaned #{primary_fa}"
          puts `#{cmd}`
          raise "something went wrong with #{cmd}" unless $?.success?
        end
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
        target = "#{target_dir}/#{file}"
        puts "copying #{wd}/#{file} => #{target}"
        FileUtils.cp("#{wd}/#{file}", target)
      }

      # copy pretext
      if y.merged
        ["hap1", "hap2"].each { |hap|
          pretext = Dir["#{wd}/*/*#{hap}*.pretext"].sort_by { |file| File.info(file).modification_time }[-1]
          target = "#{y.pretext_dir}/#{y.tol_id}.#{hap}.#{y.release_version}.curated.pretext"
          puts "copying #{pretext} => #{target}"
          FileUtils.cp(pretext, target)

          target = "#{target_dir}/#{y.tol_id}.#{hap}.#{y.release_version}.all_haplotigs.curated.fa"
          puts "creating empty hap file at => #{target}"
          File.touch(target)
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
