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
      errors.add(:guest, "already has a pending appointment request")
    end
  end

  def service_belongs_to_nutritionist
    if service && nutritionist_id && service.nutritionist_id != nutritionist_id
      errors.add(:service, "does not belong to the selected nutritionist")
    end
  end
end