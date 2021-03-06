module MingleEvents
  
  class MingleFeedCache
    
    def initialize(source, cache_dir)
      @source = source
      @cache_dir = cache_dir
      FileUtils.mkdir_p(@cache_dir)
    end
    
    
    def fetch_page(path)
      if do_not_cache(path)
        return @source.fetch_page(path)
      end
      
      cache_path = path_to_filename(path)
      fetch_and_cache(path, cache_path) unless File.exist?(cache_path)
      
      File.open(cache_path).readlines.join("\n")
    end
      
    private
    
    def do_not_cache(path)
      p, q = path_to_components(path)
      is_feed = p =~ /.*\/api\/v2\/.*\/feeds\/events\.xml/
      !is_feed || q.nil?
    end
    
    def fetch_and_cache(path, cache_path)
      FileUtils.mkdir_p(File.dirname(cache_path))
      File.open(cache_path, "w") do |f|
        f << @source.fetch_page(path)
      end
    end
    
    def path_to_components(path)
      path_as_uri = URI.parse(path)
      query = nil
      query = CGI.parse(path_as_uri.query) if path_as_uri.query
      [path_as_uri.path, query]
    end
    
    def path_to_filename(path)
      # http://devblog.muziboo.com/2008/06/17/attachment-fu-sanitize-filename-regex-and-unicode-gotcha/
      path_as_uri = URI.parse(path)
      path = "#{path_as_uri.path}?#{path_as_uri.query}"
      File.expand_path(File.join(@cache_dir, path.split('/').map{|p| p.gsub(/^.*(\\|\/)/, '').gsub(/[^0-9A-Za-z.\-]/, 'x')}))
    end
        
  end
  
end