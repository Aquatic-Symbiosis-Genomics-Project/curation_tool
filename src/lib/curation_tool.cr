require "./grit_jira_issue"
require "file_utils"

# High-level curation workflow functions used by the `curation_tool` binary.
#
# Each method accepts a `GritJiraIssue` instance (conventionally named `y`)
# and performs one step of the curation pipeline. Methods are mixed into the
# calling context via `include CurationTool`.
module CurationTool
  VERSION = "v1.2.0"

  # Initialises the HPC working directory and decompresses the assembly FASTA.
  #
  # Creates `working_dir` on disk, then concatenates the appropriate
  # decontaminated FASTA file(s) into `original.fa`:
  # - Haploid/primary+haplotigs: single `decontaminated.fa.gz` derived from the decon file path.
  # - Merged (hap1/hap2, maternal/paternal, or primary/haplotigs): both haplotype
  #   FASTA files are concatenated in order.
  #
  # Raises if `scaffolds.tpf` already exists in the working directory (guards
  # against accidentally overwriting an in-progress curation).
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

  # Builds the curated assembly FASTA from the most recent PretextView AGP file
  # and, if a `.bed` decontamination file is set, removes remaining contamination
  # intervals and regenerates the pretext map.
  #
  # Steps:
  # 1. Finds the latest `*.agp_1` file in the working directory.
  # 2. Runs `pretext-to-asm` to produce the curated FASTA.
  # 3. If a `.bed` decon file is present, runs `remove_contamination_bed` via LSF
  #    (`bsub -K`) for each haplotype (merged) or for the single primary FASTA.
  #    - For merged assemblies the hap2 decon file is derived by substituting
  #      `hap1` → `hap2` (with a fallback for partially phased naming).
  # 4. Submits `curationpretext.sh` to regenerate the pretext map (hap1 only for
  #    merged assemblies).
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
            decon_file = y.decon_file.sub("hap1", hap)

            # special case for partially phased assemblies
            if hap == "hap2" && !decon_file.includes?("hap2")
              if decon_file.includes?("primary")
                decon_file = decon_file.sub("primary", "haplotigs")
              else
                decon_file = decon_file.sub(".contamination", "alternate_contigs.contamination")
              end
              decon_file = y.decon_file unless File.exists?(decon_file)
            end
            primary_fa = "#{y.tol_id}.#{hap}.#{y.release_version}.primary.curated.fa"

            cmd = "/nfs/users/nfs_m/mh6/remove_contamination_bed -f #{primary_fa} -c #{decon_file} && mv #{primary_fa}_cleaned #{primary_fa}"
            puts `bsub -K -o debug.log -q small -M 32G -R'select[mem>32G] rusage[mem=32G]' #{cmd}`
            raise "something went wrong with #{cmd}" unless $?.success?
          }

          # Make new pretext map for hap1.
          cmd = y.curation_pretext("#{y.tol_id}.hap1.#{y.release_version}.primary.curated.fa", "#{id}.hap1.curationpretext.#{Time.utc.to_s("%Y-%m-%d_%H:%M:%S")}")
          puts `#{cmd}`
          raise "something went wrong" unless $?.success?
        else
          cmd = "/nfs/users/nfs_m/mh6/remove_contamination_bed -f #{id}.primary.curated.fa -c #{y.decon_file} && mv #{id}.primary.curated.fa_cleaned #{id}.primary.curated.fa"
          puts `bsub -K -o /dev/null -q small -M 32G -R'select[mem>32G] rusage[mem=32G]' #{cmd}`
          raise "something went wrong with #{cmd}" unless $?.success?
          # Make new pretext map.
          cmd = y.curation_pretext("#{id}.primary.curated.fa", "#{id}.curationpretext.#{Time.utc.to_s("%Y-%m-%d_%H:%M:%S")}")
          puts `#{cmd}`
          raise "something went wrong" unless $?.success?
        end
      end
    end
  end

  # Copies curated assembly files and the pretext map into the curated directory
  # for downstream QC.
  #
  # For merged assemblies, empty placeholder files are also created for the
  # haplotig FASTA and hap2 chromosome list to satisfy pipeline expectations.
  # The most recently modified `*normal.pretext` file from the curationpretext
  # output directory is selected and renamed to the canonical curated path under
  # `pretext_dir`.
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

      files = ["#{y.tol_id}.hap1.#{y.release_version}.primary.curated.fa",
               "#{y.tol_id}.hap2.#{y.release_version}.primary.curated.fa",
               "#{y.tol_id}.hap1.#{y.release_version}.primary.chromosome.list.csv",
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

  # Sets up a local workstation directory for manual curation.
  #
  # Creates a subdirectory named after the ToL ID in the current directory,
  # touches a `notes` file, and copies all matching pretext maps from the
  # `tol` server via `scp`.
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
