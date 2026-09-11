source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in activerecord-filter.gemspec
gemspec

# arel-extensions master, for three changes not yet in a released gem:
#   #14 contained_by accepts a Ruby Range
#   #15 not_overlaps exists on Attribute at all
#   #16 the positional range operators
# Drop this and raise the gemspec floor once a release carries them.
gem 'arel-extensions', github: 'malomalo/arel-extensions', branch: 'master'
