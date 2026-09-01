# Changelog

## [Unreleased]

### Security
- Require `arel-extensions` >= 9.0.1, which fixes a SQL injection in JSON path
  handling (GHSA-75hc-9q9v-9cv2). A filter key such as `"metadata.subkey"` was
  interpolated into the `#>'{...}'` array literal unescaped, so an
  attacker-controlled key could break out of the path and inject SQL.

### Changed
- JSON path predicates now render as `#> array['key']` instead of
  `#>'{key}'` (the arel-extensions fix above). PostgreSQL const-folds the array
  back to `'{key}'::text[]`, so expression indexes written against the literal
  form still match.

## [9.0.0] - 2026-08-27

### Changed
- Switched to independent Semantic Versioning. Prior releases tracked the Rails
  major/minor line; the version number no longer maps to a Rails version.
- Require Ruby >= 3.3.
- Require ActiveRecord >= 8.0 (dropped support for Rails older than 8.0).

### Added
- Gemspec `metadata` (source code, changelog, MFA-required).

### CI
- Modernized the workflow: test the Rails 8.0 and 8.1 series (resolving the
  latest patch release automatically), scope triggers to `master` with a
  cancel-in-progress concurrency group, replace the deprecated `apt-key` with a
  keyring, run MySQL as a service container, guard the sed/injection steps so a
  silent no-op fails the build, and bump `actions/checkout` to v7.

### Packaging
- Removed the deprecated `test_files` gemspec declaration.

### Documentation
- Expanded the README: AND/OR grouping, filtering across associations
  (including polymorphic), and the supported column-type predicates.

## Earlier releases

Prior versions tracked the matching Rails release. See the Git history and
RubyGems for details:

- [8.1.0] - 2026-01-06
- [8.0.0] - 2025-01-28
- [7.0.1] - 2024-09-09
- [7.0.0] - 2022-12-07
- [6.1.0] - 2021-01-14
- [6.0.0.7] - 2020-06-26

[9.0.0]: https://rubygems.org/gems/activerecord-filter/versions/9.0.0
[8.1.0]: https://rubygems.org/gems/activerecord-filter/versions/8.1.0
[8.0.0]: https://rubygems.org/gems/activerecord-filter/versions/8.0.0
[7.0.1]: https://rubygems.org/gems/activerecord-filter/versions/7.0.1
[7.0.0]: https://rubygems.org/gems/activerecord-filter/versions/7.0.0
[6.1.0]: https://github.com/malomalo/activerecord-filter/releases/tag/v6.1.0
[6.0.0.7]: https://github.com/malomalo/activerecord-filter/releases/tag/v6.0.0.7
