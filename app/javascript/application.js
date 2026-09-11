// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"

// A session that dies mid-visit (cookie expired/cleared) makes the search
// form's turbo-frame request land on Devise's sign-in page instead of a
// #results frame. Turbo would otherwise show "Content missing" inside the
// frame; this makes it do a full-page visit to the response instead, so the
// sign-in page actually renders.
document.addEventListener("turbo:frame-missing", (event) => {
  event.preventDefault()
  event.detail.visit(event.detail.response)
})
