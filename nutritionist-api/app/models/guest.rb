# app/models/guest.rb
class Guest < ApplicationRecord
  has_many :appointment_requests, dependent: :restrict_with_error

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :name, with: ->(name) { name.squish }
end