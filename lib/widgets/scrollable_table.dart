import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets filters scroll out of the way when the keyboard reduces the viewport.
class TablePageLayout extends StatelessWidget {
  final Widget controls;
  final Widget table;

  const TablePageLayout(
      {super.key, required this.controls, required this.table});

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: controls),
          SliverLayoutBuilder(builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            return SliverToBoxAdapter(
              child: SizedBox(
                height: math.max(
                    240 * textScale,
                    constraints.viewportMainAxisExtent -
                        constraints.precedingScrollExtent),
                child: table,
              ),
            );
          }),
        ],
      );
}

/// Keeps both scrollbars inside the viewport, even for very wide tables.
class TableViewport extends StatefulWidget {
  final double contentWidth;
  final Widget Function(BuildContext, ScrollController) builder;

  const TableViewport(
      {super.key, required this.contentWidth, required this.builder});

  @override
  State<TableViewport> createState() => _TableViewportState();
}

class _TableViewportState extends State<TableViewport> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  void _moveHorizontal(int direction) {
    if (!_horizontal.hasClients) return;
    final position = _horizontal.position;
    final target =
        (_horizontal.offset + direction * position.viewportDimension * 0.75)
            .clamp(0.0, position.maxScrollExtent);
    _horizontal.animateTo(target,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // The right gutter reserves room for the vertical scrollbar.
      final overflows = widget.contentWidth > constraints.maxWidth - 14;
      final behavior = ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: {
          ...ScrollConfiguration.of(context).dragDevices,
          PointerDeviceKind.mouse
        },
      );
      return ScrollConfiguration(
        behavior: behavior,
        child: ScrollbarTheme(
          data: ScrollbarTheme.of(context).copyWith(
            thumbColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.65),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.horizontal) {
                      setState(() {});
                    }
                    return false;
                  },
                  child: Scrollbar(
                    controller: _horizontal,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    thickness: 10,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    notificationPredicate: (n) =>
                        n.metrics.axis == Axis.horizontal,
                    child: Scrollbar(
                      controller: _vertical,
                      thumbVisibility: true,
                      interactive: true,
                      thickness: 10,
                      scrollbarOrientation: ScrollbarOrientation.right,
                      notificationPredicate: (n) =>
                          n.metrics.axis == Axis.vertical,
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: 14, bottom: overflows ? 16 : 0),
                        child: SingleChildScrollView(
                          controller: _horizontal,
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: SizedBox(
                            width: math.max(widget.contentWidth,
                                math.max(0, constraints.maxWidth - 14)),
                            child: widget.builder(context, _vertical),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (overflows)
                AnimatedBuilder(
                  animation: _horizontal,
                  builder: (context, _) {
                    final ready = _horizontal.hasClients &&
                        _horizontal.position.hasContentDimensions;
                    return Row(
                      children: [
                        IconButton(
                          tooltip: 'Ver columnas anteriores',
                          onPressed: ready && _horizontal.offset > 0.5
                              ? () => _moveHorizontal(-1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const Expanded(
                          child: Text('Desliza para ver más columnas',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12)),
                        ),
                        IconButton(
                          tooltip: 'Ver columnas siguientes',
                          onPressed: ready &&
                                  _horizontal.offset <
                                      _horizontal.position.maxScrollExtent - 0.5
                              ? () => _moveHorizontal(1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// A lazy table with a fixed header and independent scrolling on each axis.
class RecordTable extends StatelessWidget {
  final List<String> columns;
  final List<double> widths;
  final int rowCount;
  final Widget Function(BuildContext, int, int) cellBuilder;
  final Widget Function(BuildContext, int)? headerBuilder;
  final Color? Function(int)? rowColorBuilder;
  final double rowHeight;
  final double headerHeight;
  final String emptyMessage;

  const RecordTable(
      {super.key,
      required this.columns,
      required this.widths,
      required this.rowCount,
      required this.cellBuilder,
      this.headerBuilder,
      this.rowColorBuilder,
      this.rowHeight = 56,
      this.headerHeight = 52,
      this.emptyMessage = 'No hay registros para mostrar'})
      : assert(columns.length == widths.length);

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty) {
      return const Center(child: Text('Selecciona al menos una columna'));
    }
    if (rowCount == 0) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(emptyMessage, textAlign: TextAlign.center)));
    }
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return TableViewport(
      contentWidth: widths.fold<double>(0, (sum, width) => sum + width),
      builder: (context, vertical) => Column(
        children: [
          SizedBox(
            height: math.max(headerHeight, headerHeight * textScale),
            child: ColoredBox(
              color: colors.primaryContainer,
              child: Row(
                children: List.generate(
                    columns.length,
                    (column) => SizedBox(
                          width: widths[column],
                          child: headerBuilder?.call(context, column) ??
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Tooltip(
                                  message: columns[column],
                                  child: Text(columns[column],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: colors.onPrimaryContainer)),
                                ),
                              ),
                        )),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: vertical,
              primary: false,
              physics: const ClampingScrollPhysics(),
              itemExtent: math.max(rowHeight, rowHeight * textScale),
              itemCount: rowCount,
              itemBuilder: (context, row) => DecoratedBox(
                decoration: BoxDecoration(
                  color: rowColorBuilder?.call(row) ??
                      (row.isEven
                          ? colors.surface
                          : colors.surfaceContainerLow),
                  border:
                      Border(bottom: BorderSide(color: colors.outlineVariant)),
                ),
                child: Row(
                  children: List.generate(
                      columns.length,
                      (column) => SizedBox(
                          width: widths[column],
                          child: cellBuilder(context, row, column))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TableZoomControls extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;

  const TableZoomControls(
      {super.key, required this.scale, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
              tooltip: 'Reducir tamaño de tabla',
              onPressed: scale > 0.75
                  ? () => onChanged((scale - 0.1).clamp(0.75, 1.5))
                  : null,
              icon: const Icon(Icons.zoom_out, size: 20)),
          TextButton(
              onPressed: () => onChanged(1),
              child: Tooltip(
                  message: 'Restablecer tamaño de tabla',
                  child: Text('${(scale * 100).round()}%'))),
          IconButton(
              tooltip: 'Aumentar tamaño de tabla',
              onPressed: scale < 1.5
                  ? () => onChanged((scale + 0.1).clamp(0.75, 1.5))
                  : null,
              icon: const Icon(Icons.zoom_in, size: 20)),
        ],
      );
}

class TableTextCell extends StatelessWidget {
  final String value;
  final TextStyle? style;

  const TableTextCell(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: value,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(value,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
        ),
      );
}
