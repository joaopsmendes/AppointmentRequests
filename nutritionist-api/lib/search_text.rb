# Normalizes text for search: no accents, lowercase, single spaces.
module SearchText
  def self.normalize(text)
    I18n.transliterate(text.to_s).downcase.squish
  end
end
