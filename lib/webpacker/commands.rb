class Webpacker::Commands
  delegate :config, :compiler, :manifest, :logger, to: :@webpacker

  def initialize(webpacker)
    @webpacker = webpacker
  end

  # Keeps 2 files, the current file being used is not being considered.
  # This actually mean we should have at maximum 3 files of each name
  def clean(count = 2)
    if config.public_output_path.exist? && config.public_manifest_path.exist?

      # For each pack drops the 2 more recent files an deletes the rest.
      # The current file is not in this list, so it will never be delete.
      packs.each do |pack|
        pack.files.drop(count).each do |file|
          File.delete(file)
          logger.info "Removed #{file}"
        end
      end
    end

    true
  end

  def clobber
    config.public_output_path.rmtree if config.public_output_path.exist?
    config.cache_path.rmtree if config.cache_path.exist?
  end

  def bootstrap
    manifest.refresh
  end

  def compile
    compiler.compile.tap do |success|
      manifest.refresh if success
    end
  end

  private
    def packs
      manifest_packs.map do |pack|
        file_prefix = File.basename(pack, File.extname(pack))

        # For each pack in the manifest
        # group all files not in the manifest that matches the pack name
        # ordered by modification time desc
        file_matches = files_not_in_manifest
                      .select  { |file_name| File.basename(file_name).starts_with?("#{file_prefix}-") }
                      .sort_by { |file| File.mtime(file).utc.to_i }.reverse

        OpenStruct.new({ name: pack, files: file_matches })
      end
    end

    def manifest_packs
      manifest.refresh.keys
    end

    def files_not_in_manifest
      all_files - manifest_config - current_version
    end

    def all_files
      Dir.glob("#{config.public_output_path}/**/*")
    end

    def manifest_config
      Dir.glob("#{config.public_manifest_path}*")
    end

    def current_version
      manifest.refresh.values.map do |value|
        next if value.is_a?(Hash)

        File.join(config.root_path, "public", value)
      end.compact
    end
end
