require 'jruby/profiler'

module Rack
  # Based on rack/contrib/profiling
  #
  # Set the profile=call_tree query parameter to view a calltree profile of the request.
  #
  # Set the download query parameter to download the result locally.
  #
  # Set the no_profile query parameter to selectively turn off profiling on certain requests.
  #
  # Both the no_profile and download parameters take a tru-ish value, one of [y, yes, t, true]
  #
  class JRubyProfiler

    PRINTER_CONTENT_TYPE = {
      :flat => 'text/plain',
      :graph => 'text/plain',
      # :print_call_tree => 'text/plain',
      # :print_graph_html => 'text/html',
      # :print_tree_html => 'text/html'
    }

    PRINTERS = {
      :flat => JRuby::Profiler::FlatProfilePrinter,
      :graph => JRuby::Profiler::GraphProfilePrinter,
      # :call_tree => :print_call_tree,
      # :graph_html => :print_graph_html,
      # :tree_html => :print_tree_html
    }

    DEFAULT_PRINTER = :graph
    DEFAULT_CONTENT_TYPE = PRINTER_CONTENT_TYPE[DEFAULT_PRINTER]

    # Accepts a :times => [Fixnum] option defaulting to 1.
    def initialize(app, options = {})
      @app = app
      @stickshift = defined?(::Stickshift) && Stickshift.enabled?
      @times = (options[:times] || 1).to_i
    end

    def call(env)
      profile(env)
    end

    def profile_file
      @profile_file
    end

    private
      def profile(env)
        request  = Rack::Request.new(env.clone)
        mode = request.params.delete('profile')
        if mode.nil?
          @app.call(env)
        else
          body = StringIO.new
          @printer = parse_printer(mode)
          count  = (request.params.delete('times') || @times).to_i
          if @stickshift && count == 1
            Stickshift.output, prev_output = body, Stickshift.output
          end
          result = JRuby::Profiler.profile do
            count.times { @app.call(env) }
          end
          @uniq_id = Java::java.lang.System.nano_time
          @profile_file = ::File.expand_path( filename(@printer, env) )
          if prev_output
            Stickshift.output.puts
            Stickshift.output = prev_output
          end
          [200, headers(@printer, request, env), print(body, @printer, request, env, result)]
        end
      end

      def filename(printer, env)
        extension = printer.to_s.include?("html") ? "html" : "txt"
        "#{::File.basename(env['PATH_INFO'])}_#{printer}_#{@uniq_id}.#{extension}"
      end

      def print(body, printer, request, env, result)
        return result if printer.nil?
        filename = filename(printer, env)
        PRINTERS[printer].new(result).printProfile(java.io.PrintStream.new(body.to_outputstream))
        body.rewind
        [body.string.tap {|s| ::File.open(filename, "w") {|f| f << s } }]
      end

      def headers(printer, request, env)
        headers = { 'Content-Type' => PRINTER_CONTENT_TYPE[printer] || DEFAULT_CONTENT_TYPE }
        if boolean(request.params['download'])
          filename = filename(printer, env)
          headers['Content-Disposition'] = %(attachment; filename="#{filename}")
        end
        headers
      end

      def boolean(parameter)
        return false if parameter.nil?
        return true if %w{1 t true y yes}.include?(parameter.downcase)
        false
      end

      def parse_printer(printer)
        printer = printer.to_sym rescue nil
        if printer.nil?
          DEFAULT_PRINTER
        else
          PRINTERS.keys.include?(printer) && printer || DEFAULT_PRINTER
        end
      end
  end
end
