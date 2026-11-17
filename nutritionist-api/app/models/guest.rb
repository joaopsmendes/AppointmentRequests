class Guest < ApplicationRecord
  EMAIL_FORMAT = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/

  has_many :appointment_requests, dependent: :restrict_with_error

  validates :name, presence: true
  validates :email, presence: true, format: { with: EMAIL_FORMAT }

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :name, with: ->(name) { name.squish }
end