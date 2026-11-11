class AppointmentRequest < ApplicationRecord
  belongs_to :nutritionist
  belongs_to :service
  belongs_to :guest
end
