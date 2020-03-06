
import 'package:intl/intl.dart';
import 'package:recycling_checkin/classes.dart';

DataType stringToDataType(String s) {
  if (s == 'number') {
    return DataType.number;
  } else if (s == 'string') {
    return DataType.string;
  } else {
    // TODO: throw error instead of defaulting and catch elsewhere
    return DataType.string;
  }
}

String dataTypeToString(DataType d) {
  if (d == DataType.number) {
    return 'number';
  } else if (d == DataType.string) {
    return 'string';
  } else {
    // TODO: throw error instead of defaulting and catch elsewhere
    return 'string';
  }
}

String dateTimeToString(DateTime dt) {
  DateTime local = dt.toLocal();
  String toReturn = DateFormat.yMMMMd().add_jm().format(local);
  return toReturn;
}
