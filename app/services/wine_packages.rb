# Wine package management and the reviewing workflow that hangs off it.
#
# The models hold the data and the legal status transitions; these services
# hold the *behaviour* that must stay in one place:
#
#   WinePackages::CheckCompletion        automatic completion / reopening
#   WinePackages::MarkArrived            physical arrival + review clock
#   WinePackages::MarkCompleted          deliberate completion by a reviewer
#   WinePackages::CreateReviewFromPackage review started from a package item
#   WinePackages::Notifications::Schedule 15/5/0-day deadline reminders
#
# Tracking is deliberately absent here: it lives behind TrackingProvider, so
# the workflow never depends on a carrier.
module WinePackages
  # Raised when a workflow operation is not allowed for the current state, or
  # when an item cannot produce a review (no wine, already reviewed, ...).
  class Error < StandardError; end
end
