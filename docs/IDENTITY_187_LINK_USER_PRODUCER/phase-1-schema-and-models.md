# Phase 1: Schema and Models

**Status:** ✅ Complete

## Migration

**File:** `db/migrate/20261021234637_create_producer_memberships.rb`

```ruby
class CreateProducerMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :producer_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }, null: true
      t.timestamps
    end
    add_index :producer_memberships, [:user_id, :producer_id], unique: true
  end
end
```

## Models

### ProducerMembership (`app/models/producer_membership.rb`)
```ruby
class ProducerMembership < ApplicationRecord
  belongs_to :user
  belongs_to :producer
  belongs_to :created_by, class_name: "User", optional: true

  validates :user_id, uniqueness: { scope: :producer_id }
end
```

### User Associations (`app/models/user.rb`)
```ruby
has_many :producer_memberships, dependent: :destroy
has_many :producers, through: :producer_memberships
has_many :created_producer_memberships, class_name: "ProducerMembership", foreign_key: "created_by_id", dependent: :nullify
```

### Producer Associations (`app/models/producer.rb`)
```ruby
has_many :producer_memberships, dependent: :destroy
has_many :users, through: :producer_memberships
```

## Database Verification
```bash
$ bundle exec rails db:migrate RAILS_ENV=test
# Success - migration applied
```

## Tests
- **Model spec:** `spec/models/producer_membership_spec.rb` - 4 examples, 0 failures
  - Validates uniqueness of user_id + producer_id
  - Tests associations (user, producer, created_by)
  - Tests nullification of created_by on user deletion
  - Tests dependent destroy

## Design Decisions
1. **`created_by` nullable**: Allows existing memberships without audit trail; new ones capture the admin who created the link
2. **Unique index on (user_id, producer_id)**: Prevents duplicate links at DB level
3. **Model validation**: Provides user-friendly error message before hitting DB constraint
4. **`dependent: :nullify` for created_by**: If admin is deleted, membership remains but audit trail is cleared
5. **`dependent: :destroy` on has_many**: Removing a user/producer cleans up their memberships