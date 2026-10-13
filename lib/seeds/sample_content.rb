require "tmpdir"

module Seeds
  # Development only: the design canvas's sample content (overview §6), so the site looks like the canvas
  # as soon as it starts. Its bracketed placeholders are allowed here and nowhere else.
  #
  # - The nine sample works in canvas order: obra-01 (the real cut-out) and the eight stand-in crops from
  #   design/img, titled "Obra de muestra 01" to "09" by file, all published.
  # - obra-01's eight details in canvas order, with the canvas's alt texts.
  # - Twelve torn posters: flat tints with a faint dot screen, generated at 1600×1600.
  # - The Sobre mí and Contacto placeholders: two bracketed paragraphs, a generated 4:5 portrait, an email
  #   and an Instagram handle (only where the field is still blank).
  # One stand-in work and one poster carry a year range, so the range display shows.
  #
  # Records are found by slug or image filename, so running it again changes nothing. Images are generated
  # into temporary files with libvips (drawing and arithmetic only: this libvips has no text rendering).
  # Variants are processed inline while seeding, so they all exist when it finishes.
  class SampleContent
    IMAGES = Rails.root.join("design/img")

    # Canvas order.
    ARTWORKS = %w[01 03 08 04 02 07 06 05 09].freeze
    OBRA_01_ALT = "Collage de carteles arrancados en azules, ocres y rosas sobre papel blanco rasgado (obra de muestra)"
    STAND_IN_ALT = "Imagen provisional: fragmento de la obra de muestra"
    YEARS = "2024"
    RANGE_YEARS = "2023-2024"
    RANGE_ARTWORK = "03"
    MEDIUM = "Carteles publicitarios arrancados sobre [soporte]"
    DIMENSIONS = "[alto] × [ancho] cm"
    DESCRIPTION = "<p>[Texto breve sobre la obra, opcional: de qué calle salieron los carteles, qué capas asoman, " \
      "cuánto tiempo estuvieron a la intemperie.]</p>"

    # obra-01's details in canvas order.
    DETAILS = [
      [ "obra-01-d5.jpg", "Detalle: papel blanco arrugado sobre azul" ],
      [ "obra-01-d1.jpg", "Detalle: borde rasgado con las marcas de imprenta del cartel" ],
      [ "obra-01-d6.jpg", "Detalle: banda amarilla y cremallera impresa" ],
      [ "obra-01-d8.jpg", "Detalle: curva de trama beige junto a una forma gris" ],
      [ "obra-01-d3.jpg", "Detalle: trama de puntos de un cabello impreso" ],
      [ "obra-01-d2.jpg", "Detalle: rosa arrancado que deja ver el papel blanco" ],
      [ "obra-01-d4.jpg", "Detalle: capas rasgadas en verde y azul" ],
      [ "obra-01-d7.jpg", "Detalle: ocre, azul y verde azulado en la parte inferior" ]
    ].freeze

    POSTER_TINTS = %w[#516268 #7E5F35 #32333A #944B4F #99958B #383958 #865A47 #485749 #5A6470 #2E323C #8A5636 #5E6166].freeze
    POSTER_SIZE = 1600 # no low-resolution warning
    POSTER_PLACE = "[Lugar]"
    POSTER_CITY = "[Ciudad]"
    RANGE_POSTER = 2

    BIO = [
      "[Biografía breve: dónde vives y trabajas, desde cuándo haces collage y de dónde vienes.]",
      "[Sobre el proceso: dónde encuentras los carteles, cómo eliges los fragmentos y qué te interesa de las capas que deja la calle.]"
    ].freeze
    PORTRAIT_SIZE = [ 1600, 2000 ].freeze
    PORTRAIT_ALT = "[Retrato o foto en el taller]"
    EMAIL = "tu-correo@example.com"
    INSTAGRAM = "usuario"

    # The canvas's placeholder fills: dark dots at 20% on the tints, light dots at 7% on --surface.
    BLACK = "#000000"
    SURFACE = "#2A2A29"
    INK = "#ECEAE6"

    def initialize(output: $stdout, process_variants: true)
      @output = output
      @process_variants = process_variants
    end

    def run
      with_inline_jobs do
        Dir.mktmpdir("atesoraroseta-seeds") do |dir|
          @tmpdir = dir
          seed_artworks
          seed_details
          seed_posters
          seed_site
        end
      end
    end

    private
      # New works go to the top of the list, so the last one created ends up first: create in reverse.
      def seed_artworks
        created = ARTWORKS.reverse.count do |number|
          slug = "obra-de-muestra-#{number}"
          next false if Artwork.exists?(slug: slug)

          filename = number == "01" ? "obra-01.webp" : "obra-#{number}.jpg"
          IMAGES.join(filename).open("rb") do |io|
            Artwork.create!(
              title: "Obra de muestra #{number}", slug: slug, published: true,
              years: number == RANGE_ARTWORK ? RANGE_YEARS : YEARS,
              medium: MEDIUM, dimensions: DIMENSIONS, description: DESCRIPTION,
              image_alt: number == "01" ? OBRA_01_ALT : STAND_IN_ALT,
              image: { io: io, filename: filename }
            )
          end
        end

        @output.puts "Obras de muestra: #{created} creadas."
      end

      # New details go to the end, so they are created in canvas order.
      def seed_details
        artwork = Artwork.find_by!(slug: "obra-de-muestra-01")
        existing = filenames(artwork.details)

        created = DETAILS.count do |filename, alt|
          next false if existing.include?(filename)

          IMAGES.join(filename).open("rb") { |io| artwork.details.create!(alt: alt, image: { io: io, filename: filename }) }
        end

        @output.puts "Detalles de la obra de muestra 01: #{created} creados."
      end

      # New posters go to the top, so they are created in reverse.
      def seed_posters
        existing = filenames(TornPoster.all)

        created = POSTER_TINTS.each_with_index.reverse_each.count do |tint, index|
          number = index + 1
          filename = format("torn-poster-%02d.jpg", number)
          next false if existing.include?(filename)

          path = File.join(@tmpdir, filename)
          dot_screen(tint, dots: BLACK, opacity: 0.2, width: POSTER_SIZE, height: POSTER_SIZE).jpegsave(path, Q: 90)
          File.open(path, "rb") do |io|
            TornPoster.create!(place: POSTER_PLACE, city: POSTER_CITY, published: true,
              years: number == RANGE_POSTER ? RANGE_YEARS : YEARS, image: { io: io, filename: filename })
          end
        end

        @output.puts "Torn Posters de muestra: #{created} creados."
      end

      # Fills only what is still blank, so edits made in the development admin survive.
      def seed_site
        site = Site.first_or_create!
        added = []

        if site.about_body.blank?
          site.about_body = BIO.map { |paragraph| "<p>#{paragraph}</p>" }.join
          added << "texto de Sobre mí"
        end
        { email: [ EMAIL, "correo" ], instagram_handle: [ INSTAGRAM, "usuario de Instagram" ] }.each do |field, (value, label)|
          next if site.public_send(field).present?

          site.public_send("#{field}=", value)
          added << label
        end

        if site.portrait.attached?
          site.save!
        else
          site.portrait_alt = PORTRAIT_ALT if site.portrait_alt.blank?
          added << "retrato provisional"
          path = File.join(@tmpdir, "retrato-provisional.jpg")
          width, height = PORTRAIT_SIZE
          dot_screen(SURFACE, dots: INK, opacity: 0.07, width: width, height: height).jpegsave(path, Q: 90)
          File.open(path, "rb") do |io|
            site.portrait = { io: io, filename: "retrato-provisional.jpg" }
            site.save!
          end
        end

        @output.puts "Sobre mí y Contacto: #{added.any? ? "añadido #{added.to_sentence}" : "sin cambios"}."
      end

      def filenames(records)
        records.joins(image_attachment: :blob).pluck("active_storage_blobs.filename")
      end

      # A flat fill with the canvas's faint dot screen: radial-gradient(<dots> at <opacity> 1px,
      # transparent 1.6px) repeated every 6 px.
      def dot_screen(fill, dots:, opacity:, width:, height:)
        cell = Vips::Image.xyz(6, 6)
        distance = (((cell[0] - 2.5)**2) + ((cell[1] - 2.5)**2))**0.5
        dot = (distance * -1 + 1.6) / 0.6
        dot = (dot > 1).ifthenelse(1, (dot < 0).ifthenelse(0, dot))
        coverage = dot.replicate((width / 6.0).ceil, (height / 6.0).ceil).crop(0, 0, width, height) * opacity

        ((Vips::Image.black(width, height) + rgb(fill)) * (coverage * -1 + 1) + coverage * rgb(dots))
          .cast(:uchar).copy(interpretation: :srgb)
      end

      def rgb(hex)
        hex.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) }
      end

      def with_inline_jobs
        return yield unless @process_variants

        previous = ActiveJob::Base.queue_adapter
        ActiveJob::Base.queue_adapter = :inline
        begin
          yield
        ensure
          ActiveJob::Base.queue_adapter = previous
        end
      end
  end
end
