* Review how the Aggregate Supervisor is inserted in the application
  treez.
* Do a snapshot in the aggregate before going down  due to inactivity.
* Use the Ecto has_one/belongs_to in the Ecto Adapter.
* Provide an id to the projections to enable multiple instances
  of the same projection. This should use a Registry similarly to the one
  on Aggregates.
* Allow soft-projections. These kind of projections wont need to catchup/replay
  or to fetch missing events. A possible use case is a price ticker where
  only the last update is useful.
* We could allow the PubSub to publish events on per-aggregate or per-type
  streams. Alert: in the later the causasality is lost.
