# Article Projects — Phase 0: Repository Inspection

## Status

Complete on October 5, 2026. This is an inspection record only; no Article Project feature code was changed.

## Repository identity

| Canonical repository | Local checkout | Responsibility |
| --- | --- | --- |
| `romalopes/wine_words_api` | `/Users/romalopes/Documents/studies/my_project/wine_project/wine_prediction_api` | Rails API |
| `romalopes/wine_words_front_end` | `/Users/romalopes/Documents/studies/my_project/wine_project/wine_prediction` | React frontend |

The local Git remotes retain pre-rename names. The shared project documentation at `WINE_WORDS_README.md` confirms these local checkouts are the intended Wine Words applications.

## Verified backend findings

- Rails is pinned to `~> 8.1.3`; PostgreSQL is the database; request/model coverage primarily uses RSpec.
- `User` is the authenticated identity model. `Account` is a one-to-one profile, not the authorization identity.
- Roles are `Guest`, `Reader`, `Reviewer`, `Editor`, and `Admin` in `app/models/role.rb`.
- Existing content authorization uses `User#wine_manager?` plus ownership checks in controllers. There is no generic Permission model, policy framework, or existing `article projects.*` permission override mechanism.
- Articles and reviews each have only `draft` and `published` statuses. Article status describes visibility/publication, not granular drafting progress.
- Articles store content in `Article#body`; no existing verified article word-count service or persisted article word count was found.
- Article relationships are already modelled through `ArticleProducer`, `ArticleVintage`, and `ArticleReview`.
- Existing public/private article and review visibility uses `visible_to(current_user)` for ordinary users, while managers have broader access.
- Wine packages are the existing shipment/receipt workflow. `WinePackage` has no Article Project association and should not be changed as part of version one.

## Decisions for the feature

1. Article Project ownership will use `created_by_id` referencing `users.id` and `belongs_to :created_by, class_name: "User"`.
2. Article Project requires a separate, manual `drafting_status` string because Article status cannot represent drafting progress.
3. Article Project authorization must extend the current role/ownership convention rather than introduce an unrelated authorization framework.
4. Article Project picker and mutation paths must independently authorize linked records; owning an Article Project does not expand Article, Review, Producer, or Vintage access.
5. Article Project vintage receipt fields remain manual editorial tracking in version one. They neither create nor synchronize WinePackage records.

## Reusable backend patterns

- API routes: `config/routes.rb`
- API controller base, JWT authentication, API errors: `app/controllers/application_controller.rb`
- Pagination envelope: `app/controllers/concerns/api/paginatable.rb`
- Lean list versus full detail serializers: `app/serializers/article_list_serializer.rb` and `app/serializers/article_serializer.rb`
- Role/ownership controller checks: `app/controllers/api/v1/articles_controller.rb` and `app/controllers/api/v1/reviews_controller.rb`
- Package ownership/scope precedent: `app/controllers/concerns/wine_package_authorizable.rb`
- Package model and workflow tests: `spec/models/wine_package_spec.rb`, `spec/requests/api/v1/wine_packages_spec.rb`

## Specification adjustments

- Do not claim the application already has granular `article projects.read`, `article projects.create`, `article projects.update`, or `article projects.delete` permissions. Phase 3 must express the requested access rules using existing roles and project record scope.
- Do not reuse Article status as drafting progress. Add `article projects.drafting_status`.
- Do not assume a browser test runner exists. The frontend currently has Vitest component tests; Phase 6 must either use that coverage or explicitly introduce browser-test infrastructure as a separate decision.
- Existing controllers generally return `errors: [full message]`, not per-field error hashes. Phase 3 must establish structured project errors without breaking current API conventions.

## Exit gate

Proceed to Phase 1 only after preserving the above identity, status, visibility, package-boundary, and authorization decisions.