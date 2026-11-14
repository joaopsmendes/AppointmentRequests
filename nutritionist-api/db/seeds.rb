# Demo data: nutritionists with services, guests and appointment requests in every status.

abort "Refusing to seed the production database." if Rails.env.production?

ActiveRecord::Base.transaction do
  puts "Removing existing data..."
  AppointmentRequest.delete_all
  Guest.delete_all
  Service.delete_all
  Nutritionist.delete_all

  # --- Nutritionists and services -------------------------------------------------------
  # Service descriptions repeat across nutritionists so a search by service returns several.

  nutritionists = [
    { name: "Ana Lima", license: "3176N", services: [
      ["First appointment", 4000, 60, "Rua Augusta 120, Lisboa"],
      ["Online follow-up", 2500, 30, "Online"],
      ["Sports nutrition", 5500, 45, "Rua Augusta 120, Lisboa"]
    ] },
    { name: "João Silva", license: "3150N", services: [
      ["First appointment", 3500, 60, "Rua de Santa Catarina 45, Porto"],
      ["Follow-up", 2500, 45, "Rua de Santa Catarina 45, Porto"],
      ["Weight loss plan", 6000, 60, "Rua de Santa Catarina 45, Porto"]
    ] },
    { name: "Inês Rocha", license: "1574N", services: [
      ["Online follow-up", 2500, 30, "Online"],
      ["Vegetarian nutrition", 4500, 45, "Online"]
    ] },
    { name: "Miguel Ferreira", license: "1874N", services: [
      ["Sports nutrition", 5000, 45, "Rua de Leiria 10, Leiria"],
      ["Follow-up", 3000, 45, "Rua de Leiria 10, Leiria"]
    ] },
    { name: "Sofia Martins", license: "4021N", services: [
      ["Pediatric nutrition", 4500, 45, "Avenida Fernão de Magalhães 300, Coimbra"],
      ["First appointment", 4000, 60, "Avenida Fernão de Magalhães 300, Coimbra"],
      ["Online follow-up", 2500, 30, "Online"]
    ] },
    { name: "Tiago Sousa", license: "1498N", services: [
      ["Weight loss plan", 5500, 60, "Avenida da Liberdade 50, Braga"],
      ["Follow-up", 2800, 30, "Avenida da Liberdade 50, Braga"]
    ] },
    { name: "Beatriz Carvalho", license: "1937N", services: [
      ["Pregnancy nutrition", 5000, 60, "Rua de Santo António 25, Faro"],
      ["Online follow-up", 3000, 30, "Online"]
    ] },
    { name: "Rui Gonçalves", license: "4410N", services: [
      ["Clinical nutrition", 8000, 60, "Avenida da República 80, Lisboa"],
      ["First appointment", 4500, 60, "Avenida da República 80, Lisboa"],
      ["Follow-up", 3500, 45, "Avenida da República 80, Lisboa"]
    ] },
    { name: "Mariana Lopes", license: "1546N", services: [
      ["Vegetarian nutrition", 4000, 45, "Rua do Almada 150, Porto"],
      ["Sports nutrition", 5000, 45, "Rua do Almada 150, Porto"]
    ] },
    { name: "Pedro Almeida", license: "2756N", services: [
      ["First appointment", 3000, 60, "Online"],
      ["Online follow-up", 2500, 30, "Online"],
      ["Weight loss plan", 5000, 60, "Online"]
    ] }
  ].map do |data|
    nutritionist = Nutritionist.create!(
      name: data[:name],
      license_number: data[:license],
      photo_url: "https://api.dicebear.com/9.x/avataaars/svg?seed=#{data[:license]}"
    )

    data[:services].each do |description, price_cents, duration_minutes, location|
      nutritionist.services.create!(description: description, price_cents: price_cents,
                                    duration_minutes: duration_minutes, location: location)
    end

    nutritionist
  end

  # --- Guests and appointment requests --------------------------------------------------

  # Each guest can only have one pending request, so every request gets its own guest.
  request = lambda do |guest_name, service, scheduled_at, status: "pending"|
    email = "#{I18n.transliterate(guest_name).downcase.tr(' ', '.')}@example.com"
    guest = Guest.create!(name: guest_name, email: email)
    appointment_request = AppointmentRequest.create!(guest: guest, service: service,
                                                     nutritionist_id: service.nutritionist_id,
                                                     scheduled_at: scheduled_at)
    unless status == "pending"
      appointment_request.update_columns(status: status, answered_at: Time.current)
    end
    appointment_request
  end

  ana, joao, ines = nutritionists
  ana_first, ana_online, ana_sports = ana.services.order(:id).to_a
  day = 3.days.from_now.change(hour: 10)

  request.call("Carla Nunes", ana_first, day)                         # 10:00-11:00
  request.call("Diogo Pires", ana_first, day + 30.minutes)            # 10:30-11:30, overlaps Carla
  request.call("Eva Moreira", ana_online, day + 1.hour)               # 11:00-11:30, adjacent to Carla
  request.call("Filipe Ramos", ana_sports, day + 1.day + 5.hours)     # another day, 15:00

  # An accepted appointment: a new request for this slot gets 409 "no longer available".
  request.call("Gonçalo Teixeira", ana_first, day + 2.days, status: "accepted")
  # A rejected request, so ?status=rejected has data.
  request.call("Helena Costa", ana_online, day + 4.days, status: "rejected")

  # A few pending requests for other nutritionists.
  joao_first, joao_follow_up = joao.services.order(:id).first(2)
  request.call("Isabel Duarte", joao_first, day + 1.day)
  request.call("Jorge Mendes", joao_follow_up, day + 2.days + 4.hours)
  request.call("Leonor Batista", ines.services.order(:id).first, day + 1.day + 2.hours)
end

# --- Summary ------------------------------------------------------------------------------

puts
puts "Seeded #{Nutritionist.count} nutritionists, #{Service.count} services, " \
"#{Guest.count} guests and #{AppointmentRequest.count} appointment requests " \
"(#{AppointmentRequest.pending.count} pending, #{AppointmentRequest.accepted.count} accepted, " \
"#{AppointmentRequest.rejected.count} rejected)."

ana = Nutritionist.find_by!(license_number: "3176N")
puts
puts "Try:"
puts "  GET /api/nutritionists?q=sports"
puts "  GET /api/nutritionists/#{ana.id}/appointment_requests   (#{ana.name}: #{ana.appointment_requests.pending.count} pending)"
