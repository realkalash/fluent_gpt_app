import 'dart:convert';
import 'dart:developer';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

/// This is the main project class.
class ExcelToJson {
  /// Use this method to convert the file to a json.
  Future<String?> convert(Uint8List bytes) async {
    try {
      final Excel? excel = await _getFile(bytes);

      if (excel != null) {
        final List<String> tables = _getTables(excel);

        int index = 0;
        final Map<String, dynamic> json = {};

        for (final String table in tables) {
          List<Data?> keys = [];
          json.addAll({table: []});

          for (final List<Data?> row in excel.tables[table]?.rows ?? []) {
            try {
              if (index == 0) {
                keys = row;
                index++;
              } else {
                final Map<String, dynamic> temp = _getRows(keys, row);

                if (temp.isNotEmpty) {
                  json[table].add(temp);
                }
              }
            } on Exception catch (ex) {
              log(ex.toString());

              rethrow;
            }
          }
          index = 0;
        }

        return jsonEncode(json);
      }

      return null;
    } on Exception {
      rethrow;
    }
  }

  Map<String, dynamic> _getRows(final List<Data?> keys, final List<Data?> row) {
    final Map<String, dynamic> temp = {};
    int index = 0;
    String tk = '';

    for (final Data? key in keys) {
      if (key != null && key.value != null) {
        tk = key.value.toString();

        if (row[index] != null && row[index]!.value != null) {
          final value = row[index]!.value;

          switch (value) {
            case null:
              temp.addAll({tk: null});
            case TextCellValue():
              temp.addAll({tk: value.value.toString()});
            case FormulaCellValue():
              temp.addAll({tk: value.formula});
            case IntCellValue():
              temp.addAll({tk: value.value});
            case BoolCellValue():
              temp.addAll({tk: value.value});
            case DoubleCellValue():
              temp.addAll({tk: value.value});
            case DateCellValue():
              temp.addAll({tk: value.toString()});
            case TimeCellValue():
              temp.addAll({tk: value.toString()});
            case DateTimeCellValue():
              temp.addAll({tk: value.toString()});
            default:
              temp.addAll({tk: value.toString()});
          }
        }

        index++;
      }
    }

    return temp;
  }

  List<String> _getTables(final Excel excel) {
    final List<String> keys = [];

    for (final String table in excel.tables.keys) {
      keys.add(table);
    }

    return keys;
  }

  Future<Excel?> _getFile(List<int> bytes) async {
    try {
      return Excel.decodeBytes(bytes);
    } on Exception {
      rethrow;
    }
  }
}
