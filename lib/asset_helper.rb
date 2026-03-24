module AssetHelper
  module_function

  def needs_compilation?
    js_files = Dir.glob("app/javascript/**/*.{js,ts,tsx}")
    css_files = Dir.glob("app/assets/stylesheets/**/*.css")

    # Check if build output directory exists
    return true unless Dir.exist?("public/dev-assets")

    # Check compiled output files in public/dev-assets
    built_files = Dir.glob("public/dev-assets/*.{js,css}")
                     .select { |f| File.file?(f) }

    return true if built_files.empty?

    # Compare source files modification time with built files
    source_files = js_files + css_files
    return true if source_files.empty?

    latest_source = source_files.map { |f| File.mtime(f) }.max
    latest_built = built_files.map { |f| File.mtime(f) }.max

    # If any source file is newer than the latest built file, need recompilation
    latest_source > latest_built
  end
end
