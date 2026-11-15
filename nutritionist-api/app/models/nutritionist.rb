class Nutritionist < ApplicationRecord
  has_many :appointment_requests, dependent: :restrict_with_error
  has_many :services, dependent: :destroy

  validates :name, :license_number, presence: true
  validates :license_number, uniqueness: true

  normalizes :name, with: ->(name) { name.squish }
  normalizes :license_number, with: ->(number) { number.strip }

  before_save { self.name_search = SearchText.normalize(name) }
end