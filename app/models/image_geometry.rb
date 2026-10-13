# The pixel size a variant comes out at, computed from the original's width and height, so views can
# describe variants (srcset widths) without processing them. It matches what libvips produces; the
# custom resize_to_fill_limit operation (config/initializers/image_processing.rb) uses it too.
module ImageGeometry
  module_function

  # resize_to_limit: [box_width, nil]: scaled down to box_width, never up.
  def limit_width(width, height, box_width)
    return [ width, height ] if width <= box_width

    [ box_width, scale(height, box_width, width) ]
  end

  # resize_to_limit: [box_width, box_height]: fits inside the box, never upscaled.
  def limit(width, height, box_width, box_height)
    return [ width, height ] if width <= box_width && height <= box_height

    if width * box_height >= height * box_width
      [ box_width, scale(height, box_width, width) ]
    else
      [ scale(width, box_height, height), box_height ]
    end
  end

  # resize_to_fill_limit: [box_width, box_height]: the centre of the image, cropped to the box's aspect
  # ratio (like object-fit: cover) and scaled down to the box. An image too small to fill the box is not
  # scaled up: the largest centred crop of the box's ratio is taken at the original resolution.
  def fill_limit(width, height, box_width, box_height)
    return [ box_width, box_height ] if box_width <= width && box_height <= height

    if width * box_height > height * box_width
      [ scale(height, box_width, box_height), height ]
    else
      [ width, scale(width, box_height, box_width) ]
    end
  end

  # length × numerator / denominator, rounded, and never under 1 pixel (as in libvips).
  def scale(length, numerator, denominator)
    [ (length * numerator).fdiv(denominator).round, 1 ].max
  end
end
