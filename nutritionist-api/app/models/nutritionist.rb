# app/models/nutritionist.rb
class Nutritionist < ApplicationRecord
  has_many :services, dependent: :destroy
  has_many :appointment_requests, dependent: :restrict_with_error

  validates :name, :license_number, presence: true
  validates :license_number, uniqueness: true

  normalizes :name, with: ->(name) { name.squish }
  normalizes :license_number, with: ->(number) { number.strip }
end