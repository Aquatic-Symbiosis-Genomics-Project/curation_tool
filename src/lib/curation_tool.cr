require "./grit_jira_issue"
require "file_utils"

# High-level curation workflow functions used by the `curation_tool` binary.
#
# Each method accepts a `GritJiraIssue` instance (conventionally named `y`)
# and performs one step of the curation pipeline. Methods are mixed into the
# calling context via `include CurationTool`.
module CurationTool
  VERSION = "v1.2.1"

  # Returns the most recently modified file matching *pattern*.
  # Raises a descriptive error mentioning *description* if nothing matches.
  def latest_file(pattern : String, description : String) : String
    matches = Dir[pattern].sort_by { |file| File.info(file).modification_time }
    raise "no #{description} found matching #{pattern}" if matches.empty?
    matches[-1]
  end

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
  def setup_tol(y) : Nil
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

  # Returns the decontamination file for *hap* (`"hap1"` or `"hap2"`) of a
  # merged assembly, derived from the issue's decon file by substituting
  # `hap1` → *hap*.
  #
  # For partially phased assemblies (no `hap2` in the name) the hap2 file is
  # guessed as the `haplotigs` / `alternate_contigs` variant, falling back to
  # the original decon file if that doesn't exist.
  def hap_decon_file(y, hap : String) : String
    decon_file = y.decon_file.sub("hap1", hap)
    return decon_file if hap != "hap2" || decon_file.includes?("hap2")

    if decon_file.includes?("primary")
      decon_file = decon_file.sub("primary", "haplotigs")
    else
      decon_file = decon_file.sub(".contamination", "alternate_contigs.contamination")
    end
    File.exists?(decon_file) ? decon_file : y.decon_file
  end

  # Runs `remove_contamination_bed` on *fasta* with the BED *decon_file* via
  # LSF (`bsub -K`), replacing *fasta* in place with the cleaned version.
  def remove_contamination(fasta : String, decon_file : String) : Nil
    cmd = "/nfs/users/nfs_m/mh6/remove_contamination_bed -f #{fasta} -c #{decon_file} && mv #{fasta}_cleaned #{fasta}"
    puts `bsub -K -o /dev/null -M 8G -R'select[mem>8G] rusage[mem=8G]' #{cmd}`
    raise "something went wrong with #{cmd}" unless $?.success?
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
  def build_release(y) : Nil
    id = y.sample_dot_version
    wd = y.working_dir

    Dir.cd(wd) do
      agp = latest_file("#{wd}/*.agp_1", "AGP file")

      # create fasta
      cmd = "pretext-to-asm -a original.fa -o #{id}.fa -p #{agp}"
      puts `#{cmd}`
      raise "something went wrong with #{cmd}" unless $?.success?

      # trim contamination
      if y.decon_file.includes?(".bed")
        if y.merged
          ["hap1", "hap2"].each do |hap|
            remove_contamination("#{y.tol_id}.#{hap}.#{y.release_version}.primary.curated.fa", hap_decon_file(y, hap))
          end

          # Make new pretext map for hap1.
          cmd = y.curation_pretext("#{y.tol_id}.hap1.#{y.release_version}.primary.curated.fa", "#{id}.hap1.curationpretext.#{Time.utc.to_s("%Y-%m-%d_%H:%M:%S")}")
          puts `#{cmd}`
          raise "something went wrong" unless $?.success?
        else
          remove_contamination("#{id}.primary.curated.fa", y.decon_file)
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
  def copy_qc(y) : Nil
    target_dir = y.curated_dir
    wd = y.working_dir

    FileUtils.mkdir_p(target_dir)
    id = y.sample_dot_version

    Dir.cd(wd) do
      if y.merged
        ["hap1", "hap2"].each do |hap|
          FileUtils.touch("#{target_dir}/#{y.tol_id}.#{hap}.#{y.release_version}.all_haplotigs.curated.fa")
        end
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

      files.each do |file_name|
        file = "#{wd}/#{file_name}"
        target = "#{target_dir}/#{file_name}"
        next unless File.exists?(file)
        puts "#{file} => #{target}"
        FileUtils.cp(file, target)
      end

      # copy pretext
      if y.merged
        pretext = latest_file("#{wd}/#{id}.hap1.curationpretext.*/pretext_maps_processed/*normal.pretext", "hap1 pretext map")
        target = "#{y.pretext_dir}/#{y.tol_id}.hap1.#{y.release_version}.curated.pretext"
        puts "copying #{pretext} => #{target}"
        FileUtils.cp(pretext, target)
      else
        pretext = latest_file("#{wd}/#{id}.curationpretext.*/pretext_maps_processed/*normal.pretext", "pretext map")
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
  def setup_local(y) : Nil
    wd = "#{Dir.current}/#{y.tol_id}"
    FileUtils.mkdir_p(wd)

    cmd = <<-HERE
      touch #{wd}/notes;
      scp #{y.user}@tol:/nfs/treeoflife-01/teams/grit/data/pretext_maps/#{y.tol_id}*.pretext #{wd}/
      HERE
    puts `#{cmd}`
    raise "something went wrong" unless $?.success?
  end

  # Returns the paths of the curated primary FASTA files staged in the curated
  # assembly directory (by `copy_qc`): hap1 and hap2 for merged assemblies, the
  # single primary otherwise. Only files that exist are returned, in that order.
  def curated_fastas(y) : Array(String)
    staged_curated_files(y, "primary.curated.fa")
  end

  # Returns the paths of the chromosome list CSVs staged in the curated assembly
  # directory (by `copy_qc`): hap1 and hap2 for merged assemblies (hap2's is an
  # empty placeholder created by `copy_qc`), the single primary otherwise. Only
  # files that exist are returned, in that order.
  def curated_chromosome_lists(y) : Array(String)
    staged_curated_files(y, "primary.chromosome.list.csv")
  end

  # Checks that the number of non-empty chromosome list CSVs staged in the
  # curated directory equals the curated chromosome count in JIRA
  # (`customfield_13210`). Prints both counts.
  # Raises if the JIRA field is unset or the counts differ.
  def check_chromosome_lists(y) : Nil
    expected = y.curated_chromosomes
    raise "curated chromosome count (customfield_13210) is not set in JIRA for #{y.tol_id}" if expected.nil?

    found = curated_chromosome_lists(y).count { |path| File.size(path) > 0 }
    puts "non-empty chromosome lists: #{found}, curated chromosomes in JIRA: #{expected}"
    raise "non-empty chromosome list count (#{found}) does not match curated chromosome count in JIRA (#{expected}) for #{y.curated_dir}" if found != expected
  end

  # Builds the staged file names for merged or single primary assemblies.
  private def staged_curated_files(y, suffix : String) : Array(String)
    names = if y.merged
              ["#{y.tol_id}.hap1.#{y.release_version}.#{suffix}",
               "#{y.tol_id}.hap2.#{y.release_version}.#{suffix}"]
            else
              ["#{y.sample_dot_version}.#{suffix}"]
            end

    names.map { |name| "#{y.curated_dir}/#{name}" }.select { |path| File.exists?(path) }
  end

  # Submits BUSCO (via singularity on LSF) for the curated primary FASTA, using
  # the `busco_lineage` from the YAML.
  #
  # Runs in the curated assembly directory on the hap1 FASTA for merged assemblies, or
  # the single primary FASTA otherwise. Memory is scaled by FASTA size.
  # Output goes to `<fasta basename>.busco5` in the working directory; once the
  # job finishes its short summary is printed and copied into the working
  # directory, then the output directory (plus any `BUSCO/` and
  # `busco_downloads/`) is removed.
  # Blocks until the job finishes (`bsub -K`).
  # Raises if no curated FASTA exists (run `copy_qc` first).
  def run_busco(y) : Nil
    image = "/nfs/treeoflife-01/teams/grit/users/mh6/singularity/busco_6.1.0.sif"
    lineage_dir = "/lustre/scratch122/tol/resources/busco/latest/lineages"
    cores = 16
    wd = y.curated_dir

    fasta = curated_fastas(y).first? || raise "no curated primary FASTA in #{wd}, run --copy_qc first"

    Dir.cd(wd) do
      # set the memory
      file_size_gb = File.size(fasta) / (1024**3)
      mem_gb = if file_size_gb < 1
                 50
               elsif file_size_gb < 2
                 100
               elsif file_size_gb < 3
                 150
               else
                 220
               end

      output = "#{File.basename(fasta, ".fa")}.busco5"
      cmd = "bsub -K -n #{cores} -o /dev/null -M#{mem_gb}G -R'select[mem>#{mem_gb}G] rusage[mem=#{mem_gb}G] span[hosts=1]' " \
            "singularity exec -B /lustre #{image} busco -i #{fasta} -o #{output} -m genome -l #{lineage_dir}/#{y.busco_lineage} -c #{cores}"
      puts `#{cmd}`
      raise "something went wrong with #{cmd}" unless $?.success?

      # e.g. short_summary.specific.insecta_odb10.<output>.txt
      summary = latest_file("#{output}/short_summary.specific.*.#{output}.txt", "BUSCO short summary")
      puts File.read(summary)
      FileUtils.cp(summary, File.basename(summary))

      [output, "BUSCO", "busco_downloads"].each { |dir| FileUtils.rm_rf(dir) }
    end
  end
end
