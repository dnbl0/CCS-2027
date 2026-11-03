require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module EadCcs
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # The app stores no images, so it makes no Active Storage variants. Without a processor Rails does not load
    # ruby-vips at boot, which would otherwise need the libvips system library on every machine that runs the app
    # (image_processing 2.x no longer brings ruby-vips along).
    config.active_storage.variant_processor = :disabled

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # The service is for University of Melbourne users, so dates and times are Melbourne's.
    config.time_zone = "Melbourne"

    # Saved records (the Save buttons, the saved bar in the header and breadcrumb strip, the /bookmarks list) are hidden:
    # not part of the stakeholder review. Set SAVED_RECORDS=on to show them again; the code stays in place.
    config.x.saved_records = ENV["SAVED_RECORDS"] == "on"

    # Errors (404, 500 ...) are drawn by ErrorsController inside the site header and footer, not by the stock files in public/
    # (which stay as the fallback if that page cannot be drawn).
    # The failed request's own query string may be what failed (a broken %-encoding), so it is not passed on: the error page
    # would fail the same way. The path is still available to the page as request.original_fullpath.
    config.exceptions_app = lambda { |env|
      env["QUERY_STRING"] = ""
      # The failed request's body goes too: a POST whose body could not be read (a broken %-encoding, bad JSON) would fail again here
      env["rack.input"] = StringIO.new
      env["CONTENT_LENGTH"] = "0"
      env.delete("CONTENT_TYPE")
      %w[rack.request.query_string rack.request.query_hash action_dispatch.request.query_parameters rack.request.form_input rack.request.form_hash
         rack.request.form_pairs rack.request.form_vars rack.request.form_error action_dispatch.request.content_type action_dispatch.request.request_parameters action_dispatch.request.parameters].each { |key| env.delete(key) }
      Rails.application.routes.call(env)
    }
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
