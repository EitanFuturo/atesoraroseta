xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  @entries.each do |location, last_modified|
    xml.url do
      xml.loc location
      xml.lastmod last_modified.utc.iso8601 if last_modified
    end
  end
end
