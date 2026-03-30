//= link_tree ../builds
//= link admin.js
//= link_directory ../javascripts .js
//= link_tree ../images

# Pre-built CSS files are in app/assets/builds/ (compiled by npm run build:css)
# application.css and admin.css are NOT linked here - they contain @tailwind directives
# that Sprockets cannot process. Instead, the compiled versions come from builds/
