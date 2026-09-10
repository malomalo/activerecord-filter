source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in activerecord-filter.gemspec
gemspec

# arel-extensions master: contained_by accepts a Ruby Range (malomalo/arel-extensions#14),
# not yet in a released gem. Drop this once a release carries it.
gem 'arel-extensions', github: 'malomalo/arel-extensions', branch: 'master'
