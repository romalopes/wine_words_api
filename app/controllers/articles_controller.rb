class ArticlesController < ActionController::Base
  layout "application"
  include RequireLogin

  before_action :set_article, only: [:show, :edit, :update, :destroy,
                                     :purge_image, :add_review, :remove_review, :toggle_review_status]
  before_action :ensure_author!, only: [:edit, :update, :destroy, :purge_image,
                                        :add_review, :remove_review, :toggle_review_status]

  def index
    @scope = params[:scope] == "mine" && user_signed_in? ? "mine" : "all"
    @status = %w[draft published].include?(params[:status]) ? params[:status] : "all"

    base =
      if @scope == "mine"
        Article.where(user: current_user)
      elsif user_signed_in?
        Article.visible_to(current_user)
      else
        Article.published
      end
    base = base.where(status: @status) unless @status == "all"
    @articles = base.recent.includes(:user, :category)
  end

  def show
    if @article.status == "draft" && @article.user_id != current_user&.id
      return redirect_to articles_path, alert: "Article not found."
    end

    @linked_reviews = @article.article_reviews.includes(review: [:user, :vintage])
    @visible_reviews = @article.published_reviews.includes(:user, :vintage)
  end

  def new
    @article = Article.new
  end

  def create
    @article = Article.new(article_params)
    @article.user = current_user
    if @article.save
      attach_images
      link_reviews(@pending_review_ids)
      redirect_to @article, notice: "Article was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @article.update(article_params)
      attach_images
      link_reviews(@pending_review_ids)
      redirect_to @article, notice: "Article was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def edit
    @linked_reviews = @article.article_reviews.includes(review: [:user, :vintage])
    @visible_reviews = @article.published_reviews.includes(:user, :vintage)
  end

  def destroy
    @article.destroy
    redirect_to articles_url, notice: "Article was successfully destroyed."
  end

  def purge_image
    return redirect_to articles_path, alert: "Not allowed." unless @article.user_id == current_user&.id

    attachment = @article.images.find_by(id: params[:image_id])
    attachment&.purge
    redirect_to edit_article_path(@article), notice: "Image removed."
  end

  # --- Article <-> Review link management -------------------------------

  def add_review
    ids = Array(params[:review_ids].presence || params[:review_id]).flatten.compact
    reviews = current_user.reviews.published.where(id: ids)
    added = 0
    reviews.find_each do |review|
      next if @article.reviews.exists?(review.id)

      @article.article_reviews.create!(review: review, status: "published")
      added += 1
    end

    if added.positive?
      redirect_to edit_article_path(@article),
                  notice: "#{added} review#{'s' if added != 1} added to article."
    else
      redirect_to edit_article_path(@article), alert: "Could not add those reviews."
    end
  end

  def remove_review
    @article.article_reviews.where(review_id: params[:review_id]).destroy_all
    redirect_to edit_article_path(@article), notice: "Review removed from article."
  end

  def toggle_review_status
    link = @article.article_reviews.find_by(review_id: params[:review_id])
    link&.update(status: link.status == "published" ? "draft" : "published")
    redirect_to edit_article_path(@article), notice: "Review visibility updated."
  end

  private

  def set_article
    @article = Article.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to articles_path, alert: "Article not found."
  end

  # Author or super admin may manage an article (used by the index view too).
  def can_manage_article?(article)
    user_signed_in? &&
      (article.user_id == current_user.id || current_user.super_admin?)
  end
  helper_method :can_manage_article?

  def ensure_author!
    return if response.committed?
    return if @article&.user_id == current_user&.id
    return if current_user&.super_admin?

    redirect_to articles_path, alert: "You are not allowed to do that."
  end

  def article_params
    permitted = params.require(:article).permit(
      :title, :abstract, :body, :status, :published_at, :category_id,
      :tag_names, vintage_ids: [], review_ids: [], producer_ids: []
    )

    if permitted.key?(:tag_names)
      tag_names = permitted.delete(:tag_names).to_s.split(",").map(&:strip).reject(&:blank?)
      permitted[:tag_ids] = tag_names.map { |name| Tag.find_or_create_by_name(name)&.id }.compact
    end

    # Article has no review_ids writer; links are created after save instead.
    @pending_review_ids = Array(permitted.delete(:review_ids)).compact

    if permitted[:status] == "published"
      permitted[:published_at] ||= Time.current
    elsif permitted.key?(:status) && permitted[:status] == "draft"
      permitted[:published_at] = nil
    end

    permitted
  end

  def attach_images
    images = params[:article][:images]
    @article.images.attach(images) if images.is_a?(Array)
  end

  # Links the picked reviews (from the new-article picker) after save.
  def link_reviews(ids)
    return if ids.blank?

    current_user.reviews.published.where(id: ids).find_each do |review|
      next if @article.reviews.exists?(review.id)

      @article.article_reviews.create!(review: review, status: "published")
    end
  end
end