
import 'package:intl/intl.dart';
import 'package:recycling_checkin/classes.dart';

ModelFieldDataType stringToModelFieldDataType(String s) {
  if (s == 'number') {
    return ModelFieldDataType.number;
  } else if (s == 'string') {
    return ModelFieldDataType.string;
  } else if (s == 'select') {
    /// default to string for now
    return ModelFieldDataType.select;
  } else {
    throw new Exception('Illegal argument. Provided string does not convert to ModelFieldDataType');
  }
}

String modelFieldDataTypeToString(ModelFieldDataType d) {
  if (d == ModelFieldDataType.number) {
    return 'number';
  } else if ( d == ModelFieldDataType.string) {
    return 'string';
  } else if ( d == ModelFieldDataType.select) {
    return 'select';
  } else {
    throw new Exception('Illegal argument. Provided datatype is null or not an accepted ModelFieldDataType');
  }
}

String dateTimeToString(DateTime dt) {
  DateTime local = dt.toLocal();
  String toReturn = DateFormat.yMMMMd().add_jm().format(local);
  return toReturn;
}
