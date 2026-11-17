import { useState } from 'react'
import { formatPrice } from '../utils/formatPrice'
import { findInitialService } from '../utils/searchText'
import Avatar from './Avatar'
import { BriefcaseIcon, MapPinIcon, MoneyIcon } from './icons'

function NutritionistCard({ nutritionist, query = '', location = '', onSchedule }) {
  const { services } = nutritionist
  const [selectedServiceId, setSelectedServiceId] = useState(() => findInitialService(services, { query, location })?.id)
  const selectedService = services.find((service) => service.id === selectedServiceId)

  return (
    <article className="rounded bg-white p-6 shadow-sm">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-center gap-4">
          <Avatar name={nutritionist.name} photoUrl={nutritionist.photo_url} />
          <div>
            <h2 className="text-lg font-medium text-brand-600">{nutritionist.name}</h2>
            <p className="text-xs text-slate-500">Nutritionist • {nutritionist.license_number}</p>
          </div>
        </div>

        <div className="flex flex-col gap-2 sm:w-52">
          <button
            type="button"
            onClick={() => onSchedule?.(nutritionist, selectedService)}
            disabled={!selectedService}
            className="rounded bg-accent-100 px-4 py-2 text-sm text-accent-600 hover:bg-accent-500 hover:text-white disabled:opacity-50"
          >
            Schedule appointment
          </button>
          <button type="button" className="rounded bg-brand-50 px-4 py-2 text-sm text-brand-600">
            Website
          </button>
        </div>
      </div>

      {selectedService ? (
        <div className="mt-4 grid gap-4 text-sm sm:ml-20 sm:grid-cols-2">
          <div className="flex gap-2">
            <MapPinIcon className="mt-0.5 h-4 w-4 shrink-0 text-brand-500" />
            <div>
              <p className="font-medium text-brand-600">{selectedService.description}</p>
              <p className="text-slate-500">{selectedService.location}</p>
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <label className="flex items-center gap-2">
              <BriefcaseIcon className="h-4 w-4 shrink-0 text-brand-500" />
              <span className="sr-only">Service</span>
              <select
                value={selectedServiceId}
                onChange={(event) => setSelectedServiceId(Number(event.target.value))}
                className="cursor-pointer rounded bg-transparent py-1 text-slate-600 outline-none hover:text-brand-600 focus-visible:ring-1 focus-visible:ring-brand-500"
              >
                {services.map((service) => (
                  <option key={service.id} value={service.id}>
                    {service.description}
                  </option>
                ))}
              </select>
            </label>
            <p className="flex items-center gap-2 text-slate-600">
              <MoneyIcon className="h-4 w-4 shrink-0 text-brand-500" />
              {formatPrice(selectedService.price_cents)}
            </p>
          </div>
        </div>
      ) : (
        <p className="mt-4 text-sm text-slate-500 sm:ml-20">No services available.</p>
      )}
    </article>
  )
}

export default NutritionistCard
