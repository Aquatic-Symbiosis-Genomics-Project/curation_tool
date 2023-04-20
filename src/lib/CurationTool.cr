# TODO: Write documentation for `CurationTool`

require "http/client"
require "json"
require "yaml"
require "file_utils"

class GritJiraIssue
  @@url = "jira.sanger.ac.uk"
  @token : String?

  def initialize(name : String)
    @id = name
    @token = self.get_token
  end

  def json
    @json ||= self.get_json
  end

  def yaml
    @yaml ||= self.get_yaml
  end

  def hic_read_dir
    self.yaml["hic_read_dir"].as_s
  end

  def projects
    self.yaml["projects"].as_a
  end

  def geval_db
    if self.json["fields"]["customfield_11643"].as_s?
      self.json["fields"]["customfield_11643"].as_s
    else
      ""
    end
  end

  def decon_file
    self.json["fields"]["customfield_11677"].as_s
  end

  def release_version
    self.json["fields"]["customfield_11609"].as_f.to_i
  end

  def tol_id
    self.yaml["specimen"].as_s
  end

  # in the form of tol_id _ version
  def sample_version
    g = self.geval_db
    if g.blank?
      "#{self.tol_id}_#{self.release_version}"
    else
      g.split("_")[2..-1].join("_")
    end
  end

  # curation working directory
  def working_dir
    "/lustre/scratch123/tol/teams/grit/#{ENV["USER"]}/#{self.tol_id}_#{self.release_version}"
  end

  def pretext_dir
    prefix = self.tol_id[0]
    dir = Dir["/nfs/team135/curated_pretext_maps/#{prefix}*"].select { |f| File.directory?(f) }
    if prefix == "i"
      second = self.tol_id[1]
      dir = Dir["/nfs/team135/curated_pretext_maps/#{prefix}_*/#{second}_*/"].select { |f| File.directory?(f) }
    end
    dir[0]
  end

  # directory where the curated files go, based on the decon file  directory
  def curated_dir
    t = self.decon_file.split("/")[0..-4].join("/") + "/curated/" + self.tol_id

    if self.projects.map(&.as_s.downcase).includes? "genomeark"
      t += ".genomeark.#{self.release_version}"
    else
      t += ".#{self.release_version}"
    end
    t
  end

  def get_token : String
    File.each_line(Path["~/.netrc"].expand(home: true)) { |line|
      line = line.chomp
      columns = line.split
      return columns[-1].to_s if /#{@@url}/.match(line)
    }
    raise "cannot get token for #{@@url}"
  end

  def json
    r = HTTP::Client.get("https://jira.sanger.ac.uk/rest/api/2/issue/#{@id}", headers: HTTP::Headers{"Accept" => "application/json", "Authorization" => "Bearer #{@token}"})
    raise "cannot get the ticket" unless r.success?
    @json = JSON.parse(r.body)
  end

  def yaml
    yaml_url = self.json["fields"]["attachment"].as_a.map { |e| e["content"] }.select { |elem| /.*\.yaml/.match(elem.as_s) }[0]
    r = HTTP::Client.get("#{yaml_url}", headers: HTTP::Headers{"Authorization" => "Bearer #{@token}"})
    raise "cannot get the yaml" unless r.success?
    @yaml = YAML.parse(r.body)
  end
end

module CurationTool
  VERSION = "0.1.0"

  def setup_tol(y)
    wd = y.working_dir
    Dir.mkdir_p(wd)

    fasta_gz = y.decon_file.sub("contamination", "decontaminated.fa.gz")

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
  def build_release(y)
    id = y.sample_version
    wd = y.working_dir

    Dir.cd(wd) do
      id = y.tol_id unless File.exists?("#{id}.pretext.agp_1")
      cmd = <<-HERE
touch #{id}.additional_haplotigs.unscrubbed.fa ;
rapid_pretext2tpf_XL.py scaffolds.tpf #{id}.pretext.agp_1 ;
[ -s haps_rapid_prtxt_XL.tpf ] && rapid_join.pl -fa original.fa -tpf haps_rapid_prtxt_XL.tpf -out #{id} -hap ;
rapid_join.pl -csv chrs.csv -fa original.fa -tpf rapid_prtxt_XL.tpf -out #{id} ;
HERE
      o = `#{cmd}`
      puts o
      raise "something went wrong" unless $?.success?

      File.write(wd + "/#{y.sample_version}.curation_stats", o)

      # Make new pretext map.
      cmd = <<-HERE
  /software/grit/projects/vgp_curation_scripts/Pretext_HiC_pipeline.sh -i #{id}.curated_primary.no_mt.unscrubbed.fa -s #{id} -k #{y.hic_read_dir} -d `pwd`
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
