import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/data_service.dart';
import 'scrollable_table.dart';

class DataTableWidget extends StatefulWidget {
  final List<Map<String, String>> rows;
  final DataService service;
  final Function(int index)? onDelete;
  final Function(int index)? onRowTap;

  const DataTableWidget(
      {super.key,
      required this.rows,
      required this.service,
      this.onDelete,
      this.onRowTap});

  @override
  State<DataTableWidget> createState() => _DataTableWidgetState();
}

class _DataTableWidgetState extends State<DataTableWidget> {
  double _scale = 1;

  double _width(String column) {
    if (['CALLE', 'URBANIZA', 'REFERENCIA', 'NOMBRE'].contains(column)) {
      return 220 * _scale;
    }
    if (column == 'DISTRITO') return 180 * _scale;
    if (['NUMERO', 'DUPLICADOR'].contains(column)) return 100 * _scale;
    return 140 * _scale;
  }

  String _value(Map<String, String> row, String column) {
    final raw = row[column] ?? '';
    if (column != 'DISTRITO' || raw.isEmpty) return raw;
    final padded = raw.padLeft(2, '0');
    return widget.service.distritosMap[padded.substring(padded.length - 2)] ??
        raw;
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.service.visibleColumnsList;
    final hasActions = widget.onDelete != null || widget.onRowTap != null;
    final actionCount = 1 +
        (widget.onDelete != null ? 1 : 0) +
        (widget.onRowTap != null ? 1 : 0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                  child: Text('${widget.rows.length} registros',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold))),
              TableZoomControls(
                  scale: _scale,
                  onChanged: (value) => setState(() => _scale = value)),
            ],
          ),
        ),
        Expanded(
          child: RecordTable(
            columns: [...columns, if (hasActions) 'ACCIONES'],
            widths: [
              ...columns.map(_width),
              if (hasActions) actionCount * 48.0
            ],
            rowCount: widget.rows.length,
            rowHeight: math.max(56, 56 * _scale),
            headerHeight: math.max(48, 48 * _scale),
            emptyMessage: 'Sin resultados. Busca por NIS o medidor.',
            cellBuilder: (context, index, columnIndex) {
              final row = widget.rows[index];
              if (columnIndex == columns.length) {
                return Row(
                  children: [
                    IconButton(
                        tooltip: 'Copiar fila',
                        icon: const Icon(Icons.copy,
                            color: Colors.green, size: 20),
                        onPressed: () => _copy(
                            columns.map((c) => row[c] ?? '').join('\t'),
                            'Fila copiada')),
                    if (widget.onRowTap != null)
                      IconButton(
                          tooltip: 'Editar actividad',
                          icon: const Icon(Icons.edit,
                              color: Colors.blue, size: 20),
                          onPressed: () => widget.onRowTap!(index)),
                    if (widget.onDelete != null)
                      IconButton(
                          tooltip: 'Eliminar fila',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => widget.onDelete!(index)),
                  ],
                );
              }
              final column = columns[columnIndex];
              final value = _value(row, column);
              final activity =
                  row['Actividad'] ?? row['ACTIVIDAD'] ?? row['actividad'];
              final hasActivity =
                  activity != null && activity.isNotEmpty && activity != 'null';
              return Tooltip(
                message: value,
                child: InkWell(
                  onTap: () => _copy(value, 'Copiado: $value'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value,
                            maxLines: column == 'NIS' ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13 * _scale,
                                fontWeight: column == 'NIS'
                                    ? FontWeight.bold
                                    : FontWeight.w500)),
                        if (column == 'NIS')
                          Text(hasActivity ? activity : 'Sin actividad',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10 * _scale,
                                  color: hasActivity
                                      ? Colors.blue[800]
                                      : Colors.red[700])),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
