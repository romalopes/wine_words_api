FactoryBot.define do
  factory :follow do
    association :user
    association :followable, factory: :producer

    trait :for_wine do
      association :followable, factory: :wine
    end

    trait :for_review do
      association :followable, factory: :review
    end

    trait :for_article do
      association :followable, factory: :article
    end
  end
end