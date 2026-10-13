require "test_helper"

# Active Storage's direct uploads serve only the admin's image fields (config/initializers/direct_uploads.rb).
class Admin::DirectUploadsTest < ActionDispatch::IntegrationTest
  BLOB = { filename: "obra-nueva.jpg", byte_size: 1024, checksum: "1B2M2Y8AsgTpgAmY7PhCfg==", content_type: "image/jpeg" }.freeze

  test "a signed-out visitor can't upload" do
    assert_no_difference -> { ActiveStorage::Blob.count } do
      post rails_direct_uploads_path, params: { blob: BLOB }, as: :json
    end

    assert_response :unauthorized
  end

  test "the admin can upload" do
    sign_in_as users(:one)

    assert_difference -> { ActiveStorage::Blob.count }, 1 do
      post rails_direct_uploads_path, params: { blob: BLOB }, as: :json
    end

    assert_response :success
    assert response.parsed_body["signed_id"].present?
    assert response.parsed_body.dig("direct_upload", "url").present?
  end
end
