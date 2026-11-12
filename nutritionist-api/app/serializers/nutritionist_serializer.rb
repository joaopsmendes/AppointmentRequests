class NutritionistSerializer
  def self.render(nutritionist)
    {
      id: nutritionist.id,
      name: nutritionist.name,
      license_number: nutritionist.license_number,
      photo_url: nutritionist.photo_url,
      services: nutritionist.services.sort_by(&:id).map { |service| render_service(service) }
    }
  end

  def self.render_service(service)
    {
      id: service.id,
      description: service.description,
      price_cents: service.price_cents,
      duration_minutes: service.duration_minutes,
      location: service.location
    }
  end  
  private_class_method :render_service
end