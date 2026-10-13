require "test_helper"
require "rake"

# The task wiring only; AdminAccount and AdminCredentials have their own tests. admin:credentials is not
# run here because it writes the real credentials file.
class AdminTasksTest < ActiveSupport::TestCase
  PASSWORD = "contraseña-de-prueba-1"

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:sync")
  end

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  test "admin:sync creates the admin from ADMIN_EMAIL and ADMIN_PASSWORD, and never prints the password" do
    with_env("ADMIN_EMAIL" => "tarea@example.com", "ADMIN_PASSWORD" => PASSWORD) do
      output, errors = capture_io { Rake::Task["admin:sync"].execute }

      assert_equal "Admin: usuario tarea@example.com creado.\n", output
      assert_empty errors
      assert User.find_by(email_address: "tarea@example.com").authenticate(PASSWORD)

      output, _ = capture_io { Rake::Task["admin:sync"].execute }
      assert_equal "Admin: tarea@example.com sin cambios.\n", output
    end
  end

  test "admin:sync warns on stderr instead of failing" do
    with_env("ADMIN_EMAIL" => "tarea@example.com", "ADMIN_PASSWORD" => "abc123") do
      output, errors = capture_io { Rake::Task["admin:sync"].execute }

      assert_empty output
      assert_includes errors, "Admin: no se ha guardado tarea@example.com"
      assert_not_includes errors, "abc123"
    end
  end
end
