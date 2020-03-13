
This directory contains example JSON structures for records (record.json), models (model.json), and groups (group.json), which represent single documents under the Firebase collections _records_, _models_, and _groups_ respectively. These collection names may change. No other collections or subcollections are necessary at this moment.

Overall notes:
- all `checkoutTime`s and `checkinTime`s are Firebase timestamp types

Notes about model.json:
- the `type` field of objects under the `fields` array can take the following values: "string", "number", and "select"
    - if the above field is set to "select", then a `groupId` must be provided
- the `delay` field of objects under the fields array indicates a field that cannot be filled out until the user is about to check in.
- `groupId` within `stopData`'s `fields`'s objects is a Firebase reference type

Notes about record.json:
- the `properties` field's key-value pairs are the fields defined by the record's respective model.
- `modelId` is a Firebase reference type
