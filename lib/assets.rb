# frozen_string_literal: true

require 'opal'
require 'snabberb'
require 'uglifier'
require 'zlib'

require_relative 'js_context'

require 'pry-byebug'

class Assets
  OUTPUT_BASE = 'public'
  PIN_DIR = '/pinned/'

  # set some instance vars
  def initialize(make_map: true, compress: false, gzip: false, cache: true, precompiled: false)
    @build_path = 'build'
    @out_path = OUTPUT_BASE + '/assets'
    @root_path = '/assets'

    @main_path = "#{@out_path}/main.js"
    @deps_path = "#{@out_path}/deps.js"

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

  def game_builds
    @game_builds ||= Dir["lib/engine/game/*/game.rb"].map do |dir|
      game = dir.split('/')[-2]
      path = "#{@out_path}/#{game}.js"
      build = {
        'path' => path,
        'files' => @precompiled ? [path] : [compile_game(game)],
      }
      [game, build]
    end.to_h
  end

  def game_paths
    Dir["#{@out_path}/g_*.js"]
  end

  # returns Hash of name -> strings pointing to compiled paths; compiles them
  # iff @precompiled is false
  def builds
    @builds ||= {
      'deps' => {
        'path' => @deps_path,
        'files' => @precompiled ? [@deps_path] : [compile_lib('opal'), compile_lib('deps', 'assets')],
      },
      'main' => {
        'path' => @main_path,
        'files' => @precompiled ? [@main_path] : [compile('engine', 'lib', 'engine'), compile('app', 'assets/app', '')],
      },
      **game_builds,
    }
  end

  # HTML: <script> tags at /assets/<file>.js for all files returned by build()
  def js_tags(title)
    scripts = ['deps', 'main'].map do |key|
      file = builds[key]['path'].gsub(@out_path, @root_path)
      %(<script type="text/javascript" src="#{file}"></script>)
    end
    scripts << game_js_tag(title) if title

    scripts.compact.join
  end

  def game_js_tag(title)
    key = "g_#{title.gsub(/(.)([A-Z])/, '\1_\2').downcase}"
    return nil unless builds.key?(key)

    file = builds[key]['path'].gsub(@out_path, @root_path)
    %(<script type="text/javascript" src="#{file}"></script>)
  end

  # bundle all the files into main.js[.gz]; return array of paths
  def combine
    @combine ||=
      begin
        if @precompiled
          [@deps_path, @main_path, *game_paths]
        else
          builds.each do |_key, build|
            source = build['files'].map { |file| File.read(file).to_s }.join
            if @compress
              time = Time.now
              source = Uglifier.compile(source, harmony: true)
              puts "Compressing - #{Time.now - time}"
            end

            File.write(build['path'], source)
            Zlib::GzipWriter.open("#{build['path']}.gz") { |gz| gz.write(source) } if @gzip
          end

          [@deps_path, @main_path, *game_paths]
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
    source += "\nOpal.load('#{name}')" unless name =~ /^g_/
    source += to_data_uri_comment(source_map) if @make_map

    File.write(output, source)
    output
  end

  def lib_metadata(ns, lib_path)
    metadata = {}

    Dir["#{lib_path}/**/*.rb"].each do |file|
      next unless file.start_with?("#{lib_path}/#{ns}")
      next if file =~ %r{^lib/engine/game/g_.*/}

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

  def games_to_bundle
    @games_to_bundle ||= Dir.glob('lib/engine/*/game.rb').map { |f| f.split('/')[-2] }
  end

  def compile_game(name)
    lib_path = 'lib/engine/game'
    ns = name

    output = "#{@out_path}/#{name}.js"
    metadata = game_metadata(name)

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
    source += "\nOpal.load('engine/game/#{name}')"
    source += to_data_uri_comment(source_map) if @make_map

    File.write(output, source)
    output
  end

  def game_metadata(name)
    metadata = {}

    Dir["lib/engine/game/#{name}/**/*.rb"].each do |file|
      mtime = File.new(file).mtime
      path = file.split('/')[0..-2].join('/')

      metadata[file.gsub('lib/', '')] = {
        path: file,
        build_path: "#{@build_path}/#{path}",
        js_path: "#{@build_path}/#{file.gsub('.rb', '.js')}",
        mtime: mtime,
      }
    end

    metadata
  end
end
