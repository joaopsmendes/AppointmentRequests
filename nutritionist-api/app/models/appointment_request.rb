# app/models/appointment_request.rb
class AppointmentRequest < ApplicationRecord
  belongs_to :nutritionist
  belongs_to :service
  belongs_to :guest

  enum :status, { pending: "pending", accepted: "accepted", rejected: "rejected" }, validate: true

  before_validation :calculate_ends_at, on: :create

  validates :scheduled_at, presence: true
  validate :must_be_in_the_future, on: :create
  validate :only_one_pending_request_per_guest, on: :create
  validate :service_belongs_to_nutritionist

  scope :overlapping, ->(from, to) {
    where("tstzrange(scheduled_at, ends_at) && tstzrange(?, ?)", from, to)
  }

  # True when the nutritionist already has an accepted appointment overlapping this one.
  # Read-only check for early feedback; the exclusion constraint is the real guarantee on accept.
  def slot_taken?
    AppointmentRequest.accepted
                      .where(nutritionist_id: nutritionist_id)
                      .overlapping(scheduled_at, ends_at)
                      .where.not(id: id)
                      .exists?
  end

  # Answers the request (accepted or rejected) with a conditional UPDATE: only a pending
  # request can be answered, so a double click or two open tabs cannot answer it twice.
  # Returns true when this call answered the request, false when it was already answered.
  # Accepting may raise the no_overlapping_accepted exclusion violation.
  # The UPDATE locks the row until the transaction ends, so the same request
  # cannot be answered twice at the same time.
  def answer!(new_status)
    now = Time.current
    answered = AppointmentRequest.pending
                                 .where(id: id)
                                 .update_all(status: new_status.to_s, answered_at: now, updated_at: now)
    reload if answered == 1
    answered == 1
  end

  private

  def calculate_ends_at
    if scheduled_at && service&.duration_minutes
      self.ends_at = scheduled_at + service.duration_minutes.minutes
    end
  end

  def must_be_in_the_future
    if scheduled_at && scheduled_at <= Time.current
      errors.add(:scheduled_at, "must be in the future")
    end
  end

  def only_one_pending_request_per_guest
    if guest_id && AppointmentRequest.where(guest_id: guest_id, status: :pending).exists?
      errors.add(:guest, :pending_request_exists, message: "already has a pending appointment request")
    end
  end

  def service_belongs_to_nutritionist
    if service && nutritionist_id && service.nutritionist_id != nutritionist_id
      errors.add(:service, "does not belong to the selected nutritionist")
    end
  end
end