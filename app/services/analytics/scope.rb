# Role-scoped analytics resource sets (Phase 6).
#
# The single authorization boundary for every reporting query. Controllers
# and Phase 7 aggregation services MUST build their resource relations
# through this class — never through raw `Article.all` / visible_to calls —
# so role rules cannot drift between endpoints.
#
# Role matrix (per Phase 1 decision records):
# - Reviewer: own Articles/Reviews (`user_id = self`) + all readable Wines.
# - Editor: all readable Articles/Reviews + all readable Wines.
# - Admin: everything, including archived content (site-wide scope).
# - Reader/Guest/anonymous (nil user): no reporting access at all.
#
# "Readable" vs "reportable": reporting excludes drafts (never counted, per
# Phase 1) but INCLUDES archived content for Admin only — archived rows keep
# their events with `accepted = false` (soft archive) and must not leak
# into Reviewer/Editor reports. Owner drafts remain visible only via
# `visible_to` passthrough (see #detail_for).
#
# Unauthorized detail access returns nil and callers render 404 — never 403 —
# so resource existence is not disclosed to out-of-scope users.
module Analytics
  class Scope
    attr_reader :user

    def initialize(user)
      @user = user
    end

    # ---------------------------------------------------------------------------
    # Access predicates
    # ---------------------------------------------------------------------------

    def reporting_access?
      !@user.nil? && (@user.reviewer? || @user.role?(:editor) || @user.admin?)
    end

    # Site-wide reporting (Admin only in V1; Editor is content-scoped, not
    # site-scoped — kept as an explicit, grantable boundary).
    def site_wide?
      @user&.admin? == true
    end

    def editor?
      @user&.role?(:editor) == true
    end
    def reviewer?
      @user&.reviewer? == true
    end

    def admin?
      @user&.admin? == true
    end

    def scope_label
      if admin?
        "Site-wide"
      elsif editor?
        "All permitted content"
      else
        "Your editorial content + global Wines"
      end
    end

    # ---------------------------------------------------------------------------
    # Resource relations (role-scoped; returned as ActiveRecord::Relation)
    # ---------------------------------------------------------------------------

    def articles
      raise_forbidden! unless reporting_access?

      relation = Article.published
      relation = relation.where(user_id: @user.id) unless admin? || editor?
      relation
    end

    def reviews
      raise_forbidden! unless reporting_access?

      relation = Review.published
      relation = relation.where(user_id: @user.id) unless admin? || editor?
      relation
    end

    def wines
      raise_forbidden! unless reporting_access?

      Wine.all
    end

    # Combined editorial relation (used for `content_type=all` reports).
    # Returned as a Union scope — callers must not chain Article-only scopes
    # onto it.
    def editorial
      raise_forbidden! unless reporting_access?

      Article.published.where(user_id: editorial_user_ids)
             .or(Review.published.where(user_id: editorial_user_ids))
    end

    def editorial_user_ids
      return Article.pluck(:user_id).uniq if admin? || editor?

      [ @user.id ]
    end

    # ---------------------------------------------------------------------------
    # Detail access (nil when out of scope → controller renders 404)
    # ---------------------------------------------------------------------------

    # Returns the out-of-scope record only for Admin (own drafts/archived),
    # otherwise nil. Owner passthrough for Reviewer/Editor is handled by the
    # `articles`/`reviews` relations above — drafts they own are NOT returned
    # here because `articles`/`reviews` are `published`-only.
    def detail_for(content_type, id)
      return nil unless reporting_access?

      case content_type
      when "Article"
        articles.find_by(id: id) || (admin? && Article.find_by(id: id))
      when "Review"
        reviews.find_by(id: id) || (admin? && Review.find_by(id: id))
      when "Wine"
        wines.find_by(id: id)
      end
    end

    # ---------------------------------------------------------------------------
    # Author filter re-validation (ownership hint, never a bypass)
    # ---------------------------------------------------------------------------

    # Returns the effective author id for a requested filter, or nil when
    # the requester may not filter by that author. A Reviewer asking for
    # another author's data silently falls back to their own scope rather
    # than erroring, so filter probes never confirm whether the requested
    # author exists.
    def effective_author_id(requested_id)
      return nil unless requested_id.present?

      return requested_id.to_i if admin? || editor?

      @user.id # Reviewer: always own scope
    end

    # ---------------------------------------------------------------------------
    # Period shortcuts (convenience for controllers — see Analytics::Period
    # for canonical window resolution)
    # ---------------------------------------------------------------------------

    def default_period_key
      "30d"
    end

    def max_lookback_days
      90
    end

    # ---------------------------------------------------------------------------
    # Access control helper
    # ---------------------------------------------------------------------------

    def raise_forbidden!
      raise ActionController::Forbidden, "Reporting access requires Reviewer, Editor, or Admin role"
    end

    # __PART3__
  end
end
