require 'spec_helper'

describe "AwesomeNestedSet" do
  include SqlAssertions

  before(:all) do
    self.class.fixtures :users, :categories
  end

  after(:all) do
    SqlAssertions::SQLCounter.clear_log
  end

  let(:adapter_name) { User.connection.adapter_name.downcase }

  describe "move_left" do
    it 'locks rows for update' do
      child = users(:child_2)

      sql = case adapter_name
      when /postgres/
        'SELECT "users".* FROM "users" WHERE "users"."id" = $1 LIMIT $2 FOR UPDATE'
      when /mysql/
        "SELECT `users`.* FROM `users` WHERE `users`.`id` = #{child.id} LIMIT 1 FOR UPDATE"
      end

      assert_sql(sql) do
        child.move_left
      end
    end
  end

  describe 'first_or_create!' do
    it 'locks the parent for update' do
      parent = User.first

      sql = case adapter_name
      when /postgres/
        "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"id\" = $1 LIMIT $2 FOR UPDATE"
      when /mysql/
        "SELECT `users`.* FROM `users` WHERE `users`.`id` = #{parent.id} LIMIT 1 FOR UPDATE"
      end

      assert_sql(sql) do
        User.where(name: "Chris-#{Time.current.to_f}").first_or_create! do |user|
          user.parent = parent
        end
      end
    end
  end

  describe "root" do
    it 'adds the scope if scoped' do
      sql = case adapter_name
      when /postgres/
        "SELECT \"categories\".* FROM \"categories\" WHERE \"categories\".\"organization_id\" = $1 AND \"categories\".\"parent_id\" IS NULL ORDER BY \"categories\".\"lft\" ASC LIMIT $2"
      when /mysql/
        "SELECT `categories`.* FROM `categories` WHERE `categories`.`organization_id` = 1 AND `categories`.`parent_id` IS NULL ORDER BY `categories`.`lft` ASC LIMIT 1"
      end
      categories(:top_level).update_attribute :organization_id, 999999999
      assert_sql(sql) do
        ScopedCategory.where(organization_id: 1).root
      end
    end
  end
end
