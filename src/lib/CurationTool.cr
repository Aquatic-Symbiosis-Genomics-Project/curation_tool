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
    self.json
    self.yaml
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
	# mkdir /lustre/scratch123/tol/teams/grit/tom_mathers/curations/<tol_ID>
	wd = "/lustre/scratch123/tol/teams/grit/#{ENV["USER"]}/#{y.yaml["specimen"]}"
	Dir.mkdir_p(wd)
  
	# ln -s /lustre/scratch124/tol/projects/darwin/data/<path> . ; curation_v2;cursetup

	# get file_to_curate
	fasta_gz = y.json["fields"]["customfield_11677"].as_s.sub("curation","decontaminated.fa.gz")
	FileUtils.ln_sf(fasta_gz ,"#{wd}/")
        cmd = <<-HERE
cd #{wd};
zcat *.fa.gz > original.fa ; 
perl /software/grit/projects/vgp_curation_scripts/rapid_split.pl -fa original.fa ; 
mv -f original.fa.tpf original.tpf ;
cp original.tpf scaffolds.tpf;
HERE
    puts cmd
    puts `#{cmd}`
    raise "something went wrong" unless $?.success?
  end


  # copy pretext
  def setup_local(yaml)
    wd = "#{Dir.current}/#{yaml["specimen"]}"

    cmd = <<-HERE
mkdir -p #{wd};
touch #{wd}/notes;
scp #{ENV["USER"]}@tol:/nfs/team135/pretext_maps/#{yaml["specimen"]}*.pretext #{wd}/
HERE
    puts cmd
    puts `#{cmd}`
    raise "something went wrong" unless $?.success?
  end

  # copy for QC
  def copy_qc(j, d)
    # nab the decontaminated file from Jira? and use the basedir from that?
    target_dir = j["fields"]["customfield_11677"].to_s
    target_dir = target_dir.split("/")[0..-3].join("/")
    target_dir = "#{target_dir}/curated/#{j["fields"]["customfield_11627"]}.#{j["fields"]["customfield_11609"].as_f.to_i}"

    # sample_id + release_version | or from geval database
    input = j["fields"]["customfield_11643"].to_s.split("_")[-2..-1].join("_")
    ["rapid_prtxt_XL.tpf",
     "haps_rapid_prtxt_XL.tpf",
     "#{input}.curated_primary.no_mt.unscrubbed.fa",
     "#{input}.inter.csv",
     "#{input}.additional_haplotigs.unscrubbed.fa",
     "#{input}.chromosome.list.csv",
     "#{input}.curated.agp"].each { |f|
      puts "copying #{d}/#{f} => #{target_dir}/#{f}"
      puts File.copy("#{d}/#{f}","#{target_dir}/#{f})")
    }
  end


  # rapid_pretext2tpf_XL.py scaffolds.tpf <tol_id>.pretext.agp_
  # rapid_join.pl -csv chrs.csv -fa original.fa -tpf rapid_prtxt_XL.tpf -out <tol_id>
  # Make new pretext map.
end
