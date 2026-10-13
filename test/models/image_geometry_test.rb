require "test_helper"

# Sizes were checked against libvips' own output for these and 40 random sizes (see the WP2 handoff).
class ImageGeometryTest < ActiveSupport::TestCase
  test "limit_width scales down to the width and never up" do
    assert_equal [ 600, 799 ], ImageGeometry.limit_width(1179, 1571, 600)
    assert_equal [ 1179, 1571 ], ImageGeometry.limit_width(1179, 1571, 1200)
    assert_equal [ 2400, 1800 ], ImageGeometry.limit_width(4032, 3024, 2400)
    assert_equal [ 600, 1 ], ImageGeometry.limit_width(2401, 1, 600), "never under 1 px"
  end

  test "limit fits inside a box" do
    assert_equal [ 240, 320 ], ImageGeometry.limit(1179, 1571, 320, 320)
    assert_equal [ 320, 240 ], ImageGeometry.limit(800, 600, 320, 320)
    assert_equal [ 473, 630 ], ImageGeometry.limit(1179, 1571, 1200, 630)
    assert_equal [ 300, 200 ], ImageGeometry.limit(300, 200, 1200, 630)
  end

  test "fill_limit crops to the box's ratio, and scales down to fill it" do
    assert_equal [ 600, 600 ], ImageGeometry.fill_limit(800, 600, 600, 600)
    assert_equal [ 600, 750 ], ImageGeometry.fill_limit(1179, 1571, 600, 750)
  end

  test "fill_limit takes the largest centred crop of the box's ratio when the image is too small" do
    assert_equal [ 600, 600 ], ImageGeometry.fill_limit(800, 600, 1200, 1200)
    assert_equal [ 1500, 1500 ], ImageGeometry.fill_limit(2000, 1500, 2400, 2400)
    assert_equal [ 1179, 1474 ], ImageGeometry.fill_limit(1179, 1571, 1200, 1500)
    assert_equal [ 336, 420 ], ImageGeometry.fill_limit(340, 420, 600, 750)
    assert_equal [ 1, 1 ], ImageGeometry.fill_limit(2401, 1, 600, 600)
  end
end
