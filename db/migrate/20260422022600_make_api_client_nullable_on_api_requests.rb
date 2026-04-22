class MakeApiClientNullableOnApiRequests < ActiveRecord::Migration[8.1]
  def change
    change_column_null :api_requests, :api_client_id, true
  end
end
