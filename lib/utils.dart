
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