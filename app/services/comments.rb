# Commenting on wines, reviews and articles. One polymorphic Comment model for
# all three, with one level of replies.
#
#   Comments::Permission  who may comment / reply / edit / delete
#
# The model holds the hierarchy rules (see Comment); the controllers under
# Api::V1 own the HTTP shape and reuse CommentableActions for the three
# commentable endpoints.
module Comments
  class Error < StandardError; end
end