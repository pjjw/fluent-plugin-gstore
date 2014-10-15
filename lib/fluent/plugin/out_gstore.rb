module Fluent


class GStoreOutput < Fluent::TimeSlicedOutput
  Fluent::Plugin.register_output('gstore', self)

  def initialize
    super
    require 'gstore'
    require 'kconv'
    require 'zlib'
    require 'time'
    require 'tempfile'
    require "pathname"
    require "rexml/document"
  end

  config_param :path, :string, :default => ""
  config_param :time_format, :string, :default => nil

  config_param :gstore_key_id, :string
  config_param :gstore_sec_key, :string
  config_param :gstore_bucket, :string

  config_param :format, :string, :default => 'out_file'

  def configure(conf)
    super

    @formatter = TextFormatter.create(conf)
  end

  def start
    super
    options = {
      :access_key => @gstore_key_id,
      :secret_key => @gstore_sec_key
    }
    @gstore = GStore::Client.new(options)
  end

  def format(tag, time, record)
    @formatter.format(tag, time, record)
  end

  def exists?(source)
    begin
      REXML::Document.new source
      # :TODO
      false
    rescue REXML::ParseException => e
      true
    rescue Exception => e
      true
    end
  end

  def write(chunk)
    i = 0
    begin
      gstorepath = "#{@path}#{chunk.key}_#{i}.gz"
      i += 1
    end while exists? @gstore.get_object(@gstore_bucket, gstorepath)

    tmp = Tempfile.new("gstore-")
    w = Zlib::GzipWriter.new(tmp)
    begin
      chunk.write_to(w)
      w.close
      @gstore.put_object(
        @gstore_bucket,
        gstorepath,
        :data => Pathname.new(tmp.path).read())
    ensure
      w.close rescue nil
    end
  end
end


end
