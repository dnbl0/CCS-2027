require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The modal contract that needs no browser: the "You're leaving this site" dialog's markup, and the shared stylesheet and
# script that lock the page behind every modal (the behaviour itself is in test/system/modal_scroll_lock_test.rb).
class ModalTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  Action = Struct.new(:key)

  def page = Capybara::Node::Simple.new(rendered_content)

  def stylesheet(name) = Rails.root.join("app/assets/stylesheets", name).read

  def script(name) = Rails.root.join("app/javascript", name).read

  test "the leaving-site dialog is a modal <dialog> with the Gen 3 Close button first and no Bootstrap close icon" do
    render_inline(NexusCcs::ViewFullRecordComponent.new(document: SolrDocument.new("id" => "x1", "collection_ssim" => [ "Medical History Museum" ], "source_url_ss" => "https://collections.example.org/objects/x1"), action: Action.new(:view_full_record)))

    assert_selector "dialog.modal.uom-modal[aria-labelledby]"
    assert_selector "dialog .modal-content > button.modal-close:first-child", text: "Close"
    assert_no_selector "dialog .btn-close"
    assert_selector "dialog .modal-header h2.modal-title"
    assert_selector "dialog .modal-footer a.btn-primary[target=_blank][rel~=noopener]", text: "Continue to site"
  end

  test "the shared stylesheet locks the root for open dialogs and for html.has-open-modal, and keeps the scrollbar gutter" do
    css = stylesheet("components/modal.css")

    assert_includes css, "html:has(dialog[open]),\nhtml.has-open-modal {"
    assert_match(/overflow: hidden;\s+scrollbar-gutter: stable;/, css)
    assert_includes css, "dialog.modal[open] {\n  overscroll-behavior: contain;"
    assert_includes Rails.root.join("app/assets/stylesheets/application.css").read, "components/modal.css"
  end

  test "every backdrop is the navy 80% blanket" do
    assert_equal "rgb(0 11 52 / 80%)", stylesheet("tokens/primitives.css")[/--ccs-scrim: ([^;]+);/, 1]
    assert_includes stylesheet("components/modal.css"), "--bl-modal-backdrop-bg: var(--ccs-scrim)"
    assert_includes stylesheet("components/modal.css"), "dialog::backdrop"
    assert_includes stylesheet("components/filter_drawer.css"), "background: var(--ccs-scrim);"
  end

  test "the confirmation dialogs are square white panels padded 24px with the Close button top right" do
    css = stylesheet("components/modal.css")

    assert_includes css, "--bs-modal-border-radius: var(--ccs-radius-none);"
    assert_match(/dialog\.uom-modal \.modal-content \{[^}]*padding: var\(--ccs-space-5\);/m, css)
    assert_match(/dialog\.uom-modal \.modal-close \{[^}]*position: absolute;[^}]*top: 1\.625rem;[^}]*right: 1\.25rem;/m, css)
  end

  test "the surfaces that are not a dialog take part in the shared lock and release it when torn down" do
    lock = script("modal_lock.js")
    assert_includes lock, "export function lockScroll"
    assert_includes lock, "export function unlockScroll"
    assert_includes lock, "turbo:before-cache"
    assert_includes Rails.root.join("config/importmap.rb").read, 'pin "modal_lock"'

    %w[controllers/filter_drawer_controller.js controllers/search_overlay_controller.js].each do |name|
      source = script(name)
      assert_includes source, 'from "modal_lock"', "#{name} uses the shared lock"
      assert_includes source, "lockScroll(this)"
      assert_includes source, "unlockScroll(this)"
      assert_match(/disconnect\(\) \{.*unlockScroll\(this\)/m, source, "#{name} releases the lock when Turbo removes it")
    end
    assert_no_match(/filter-drawer-open/, stylesheet("components/filter_drawer.css"))
  end

  test "a dialog is closed when Turbo removes it, so a cached page is never restored with one stuck open" do
    assert_match(/disconnect\(\) \{.*dialogTarget\.close\(\)/m, script("controllers/dialog_controller.js"))
  end
end
