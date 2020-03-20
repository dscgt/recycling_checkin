
import 'package:intl/intl.dart';
import 'package:recycling_checkin/classes.dart';

ModelFieldDataType stringToModelFieldDataType(String s) {
  if (s == 'number') {
    return ModelFieldDataType.number;
  } else if (s == 'string') {
    return ModelFieldDataType.string;
  } else {
    // TODO: throw error instead of defaulting and catch elsewhere
    return ModelFieldDataType.string;
  }
}

String modelFieldDataTypeToString(ModelFieldDataType d) {
  if (d == ModelFieldDataType.number) {
    return 'number';
  } else if (d == ModelFieldDataType.string) {
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
