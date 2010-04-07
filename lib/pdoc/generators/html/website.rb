module PDoc
  module Generators
    module Html
      
      unless defined? TEMPLATES_DIRECTORY
        TEMPLATES_DIRECTORY = File.join(TEMPLATES_DIR, "html")
      end
      
      class Website < AbstractGenerator
        
        include Helpers::BaseHelper
        include Helpers::LinkHelper
        
        class << Website
          attr_accessor :syntax_highlighter
          attr_accessor :markdown_parser
          def pretty_urls?
            !!@pretty_urls
          end
          
          def pretty_urls=(boolean)
            @pretty_urls = boolean
          end
        end
        
        def initialize(parser_output, options = {})
          super
          @templates_directory = File.expand_path(options[:templates] || TEMPLATES_DIRECTORY)
          @index_page = options[:index_page] && File.expand_path(options[:index_page])
          Website.syntax_highlighter = SyntaxHighlighter.new(options[:syntax_highlighter])
          Website.pretty_urls = options[:pretty_urls]
          set_markdown_parser(options[:markdown_parser])
          load_custom_helpers
        end
        
        def set_markdown_parser(parser = nil)
          parser = :rdiscount if parser.nil?
          case parser.to_sym
          when :rdiscount
            require 'rdiscount'
            Website.markdown_parser = RDiscount
          when :bluecloth
            require 'bluecloth'
            Website.markdown_parser = BlueCloth
          when :maruku
            require 'maruku'
            Website.markdown_parser = Maruku
          else
            raise "Requested unsupported Markdown parser: #{parser}."
          end
        end
        
        def load_custom_helpers
          begin
            require File.join(@templates_directory, "helpers")
          rescue LoadError => e
            return nil
          end
          self.class.__send__(:include, Helpers::BaseHelper)
          Page.__send__(:include, Helpers::BaseHelper)
          Helpers.constants.map(&Helpers.method(:const_get)).each(&DocPage.method(:include))
        end
        
        # Generates the website to the specified directory.
        def render(output)
          @depth = 0
          path = File.expand_path(output)
          FileUtils.mkdir_p(path)
          Dir.chdir(path) do
          
            render_index
            copy_assets
          
            root.sections.each do |section|
              @depth = 0
              render_template('section', { :doc_instance => section })
            end

            dest = File.join("javascripts", "item_index.js")
            DocPage.new("item_index.js", false, variables).render_to_file(dest)
          end
        end
        
        def render_index
          vars = variables.merge(:index_page_content => index_page_content, :home => true)
          DocPage.new('index', 'layout', vars).render_to_file('index.html')
        end
        
        def render_template(template, var = {})
          @depth += 1
          doc = var[:doc_instance]
          dest = File.join(*raw_path_to(doc))
          puts "        Rendering #{dest}..."
          FileUtils.mkdir_p(dest)
          DocPage.new(template, variables.merge(var)).render_to_file(File.join(dest, 'index.html'))
          render_children(doc)
          @depth -= 1
        end
        
        def render_children(obj)
          [:namespaces, :classes, :mixins].each do |prop|
            obj.send(prop).each(&method(:render_node)) if obj.respond_to?(prop)
          end
          
          obj.utilities.each(&method(:render_leaf)) if obj.respond_to?(:utilities)
          render_leaf(obj.constructor) if obj.respond_to?(:constructor) && obj.constructor
          
          [:instance_methods, :instance_properties, :class_methods, :class_properties, :constants].each do |prop|
            obj.send(prop).each(&method(:render_leaf)) if obj.respond_to?(prop)
          end
        end
        
        # Copies the content of the assets folder to the generated website's
        # root directory.
        def copy_assets
          FileUtils.cp_r(Dir.glob(File.join(@templates_directory, "assets", "**")), '.')
        end
        
        def render_leaf(object)
          is_proto_prop = is_proto_prop?(object)
          @depth += 1 if is_proto_prop
          render_template('leaf', { :doc_instance => object })
          @depth -= 1 if is_proto_prop
        end
        
        def render_node(object)          
          render_template('node', { :doc_instance => object })
        end
        
        private
          def variables
            {
              :root => root,
              :depth => @depth,
              :templates_directory => @templates_directory,
              :name => @options[:name],
              :short_name => @options[:short_name] || @options[:name],
              :home_url => @options[:home_url],
              :doc_url => @options[:doc_url],
              :version => @options[:version],
              :copyright_notice => @options[:copyright_notice]
            }
          end
          
          def is_proto_prop?(object)
            object.is_a?(Models::InstanceMethod) ||
              object.is_a?(Models::InstanceProperty)
          end
          
          def index_page_content
            @index_page ? htmlize(File.read(@index_page)) : nil
          end
      end
    end
  end
end
