# Single source of truth for who may do what with comments.
#
# The API enforces this server-side; the React UI only mirrors it to decide what
# to render. Two CAPABILITIES are kept deliberately separate:
#
#   participate — writing a comment or a reply. Any signed-in account except
#                 the base "Guest" role (see User#commenter?).
#   moderate    — editing or deleting somebody else's comment. Editors and
#                 Admins only (see User#comment_moderator?).
#
# Keeping them apart means adding a moderation tier later never changes who can
# comment, and widening commenting never grants edit powers.
module Comments
  class Permission
    def initialize(user)
      @user = user
    end

    def can_comment?
      return false if @user.nil?

      @user.commenter?
    end

    def can_reply?
      can_comment?
    end

    # Authors may edit their own comment (but not one that is already soft
    # deleted — that tombstone is final). Moderators may edit anyone's.
    def can_edit?(comment)
      return false if @user.nil? || comment.nil?
      return false if comment.deleted?

      own?(comment) || moderator?
    end

    # Same rule as editing: author or moderator. Delete is soft, so the thread
    # keeps its shape.
    def can_delete?(comment)
      return false if @user.nil? || comment.nil?
      return false if comment.deleted?

      own?(comment) || moderator?
    end

    def moderator?
      @user.present? && @user.comment_moderator?
    end

    private

    # Modelled on the rest of the API: authorization always runs against the
    # impersonated (effective) user, so an Admin browsing as a Guest is treated
    # like a Guest.
    def own?(comment)
      comment.user_id == @user.id
    end
  end
end