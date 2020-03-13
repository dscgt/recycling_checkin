
This directory contains example JSON structures for records (record.json), models (model.json), and groups (group.json), which represent single documents under the Firebase collections _records_, _models_, and _groups_ respectively. These collection names may change. No other collections or subcollections are necessary at this moment.

Notes about model.json:
- the `type` field of objects under the `fields` array can take the following values: "string", "number", and "select"
    - if the above field is set to "select", then a `groupId` must be provided
- the `delay` field of objects under the fields array indicates a field that cannot be filled out until the user is about to check in.

Notes about record.json:
- the `properties` field's key-value pairs are the fields defined by the record's respective model.
