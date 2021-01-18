# frozen_string_literal: true

require 'opal'
require 'snabberb'
require 'uglifier'
require 'zlib'

require_relative 'js_context'

class Assets
  OUTPUT_BASE = 'public'
  PIN_DIR = '/pinned/'

  # set some instance vars
  def initialize(make_map: true, compress: false, gzip: false, cache: true, precompiled: false)
    @build_path = 'build'
    @out_path = OUTPUT_BASE + '/assets'
    @root_path = '/assets'

    @main_path = "#{@out_path}/main.js"
    @opal_path = "#{@out_path}/opal.js"

    @cache = cache
    @make_map = make_map
    @compress = compress
    @gzip = gzip
    @precompiled = precompiled
  end

  # create a new MiniRacer JS Context
  def context
    @context ||= JsContext.new(combine)
  end

  def html(script, **needs)
    context.eval(Snabberb.html_script(script, **needs))
  end

  # returns Hash of name -> strings pointing to compiled paths; compiles them
  # iff @precompiled is false
  def builds
    if @precompiled
      {
        'opal' => {
          'path' => @opal_path,
          'files' => [@opal_path],
        },
        'main' => {
          'path' => @main_path,
          'files' => [@main_path],
        },
      }
    else
      @builds ||= {
        'opal' => {
          'path' => @opal_path,
          'files' => [compile_lib('opal')],
        },
        'main' => {
          'path' => @main_path,
          'files' => [
            compile_lib('deps', 'assets'),
            compile('engine', 'lib', 'engine'),
            compile('app', 'assets/app', ''),
          ],
        },
      }
    end
  end

  # HTML: <script> tags at /assets/<file>.js for all files returned by build()
  def js_tags
    builds.values.map { |v| v['files'] }.flatten.map do |file|
      file = file.gsub(@out_path, @root_path)
      %(<script type="text/javascript" src="#{file}"></script>)
    end.join
  end

  # bundle all the files into main.js[.gz]; return array of paths
  def combine
    @combine ||=
      begin
        if @precompiled
          [@opal_path, @main_path]
        else
          builds.each do |key, build|
            source = build['files'].map { |file| File.read(file).to_s }.join
            if @compress
              time = Time.now
              source = Uglifier.compile(source, harmony: true)
              puts "Compressing - #{Time.now - time}"
            end
            File.write(build['path'], source)
            Zlib::GzipWriter.open("#{build['path']}.gz") { |gz| gz.write(source) } if @gzip
          end

          [@opal_path, @main_path]
        end
      end
  end

  def compile_lib(name, *append_paths)
    builder = Opal::Builder.new
    append_paths.each { |ap| builder.append_paths(ap) }
    path = "#{@out_path}/#{name}.js"
    if !@cache || !File.exist?(path)
      time = Time.now
      File.write(path, builder.build(name))
      puts "Compiling #{name} - #{Time.now - time}"
    end
    path
  end

  def compile(name, lib_path, ns = nil)
    output = "#{@out_path}/#{name}.js"
    metadata = lib_metadata(ns || name, lib_path)

    compilers = metadata.map do |file, opts|
      FileUtils.mkdir_p(opts[:build_path])
      js_path = opts[:js_path]
      next if @cache && File.exist?(js_path) && File.mtime(js_path) >= opts[:mtime]

      Opal::Compiler.new(File.read(opts[:path]), file: file, requirable: true)
    end.compact

    return output if compilers.empty?

    if @make_map
      sm_path = "#{@build_path}/#{name}.json"
      sm_data = File.exist?(sm_path) ? JSON.parse(File.binread(sm_path)) : {}
    end

    compilers.each do |compiler|
      file = compiler.file
      raise "#{file} not found put in deps." unless (opts = metadata[file])

      time = Time.now
      File.write(opts[:js_path], compiler.compile)
      puts "Compiling #{file} - #{Time.now - time}"
      next unless @make_map

      source_map = compiler.source_map
      code = source_map.generated_code + "\n"
      sm_data[file] = {
        'lines' => code.count("\n"),
        'map' => source_map.to_h,
      }
    end

    File.write(sm_path, JSON.dump(sm_data)) if @make_map

    source_map = {
      version: 3,
      file: "#{name}.js",
      sections: [],
    }

    offset_line = 0

    source = metadata.map do |file, opts|
      if @make_map
        sm = sm_data[file]

        source_map[:sections] << {
          offset: {
            line: offset_line,
            column: 0,
          },
          map: sm['map'],
        }

        offset_line += sm['lines']
      end

      File.read(opts[:js_path]).to_s
    end.join("\n")
    source += "\nOpal.load('#{name}')"
    source += to_data_uri_comment(source_map) if @make_map
    File.write(output, source)
    output
  end

  def lib_metadata(ns, lib_path)
    metadata = {}

    Dir["#{lib_path}/**/*.rb"].each do |file|
      next unless file.start_with?("#{lib_path}/#{ns}")

      mtime = File.new(file).mtime
      path = file.split('/')[0..-2].join('/')

      metadata[file.gsub("#{lib_path}/", '')] = {
        path: file,
        build_path: "#{@build_path}/#{path}",
        js_path: "#{@build_path}/#{file.gsub('.rb', '.js')}",
        mtime: mtime,
      }
    end

    metadata
  end

  def to_data_uri_comment(source_map)
    map_json = JSON.dump(source_map)
    "//# sourceMappingURL=data:application/json;base64,#{Base64.encode64(map_json).delete("\n")}"
  end
end
