import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:vector_editor/graphics/image_data.dart';
import 'package:vector_editor/graphics/shapes/shape_visitor.dart';

import '../drawing.dart';
import 'line.dart';
import 'shape.dart';

class Polygon extends Shape {
  final List<ui.Offset> points;
  bool closed;
  int thickness;
  ui.Color? fillColor;
  ImageData? _fillImage;

  ImageData? get fillImage => _fillImage;

  set fillImage(ImageData? value) {
    _fillImage = value;
    updateBoundingBox();
  }

  ui.Offset? topLeft;
  ui.Offset? bottomRight;

  Polygon(this.points, ui.Offset offset,
      {this.closed = false,
      this.thickness = 1,
      this.fillColor,
      super.outlineColor,
      ImageData? fillImage})
      : super(offset) {
    this.fillImage = fillImage;
  }

  @override
  List<Handle> get handles {
    final handles = <Handle>[];
    for (var i = 0; i < points.length; i++) {
      handles.add(Handle(points[i], onMove: (offset) {
        points[i] += offset;
        if (fillImage != null) updateBoundingBox();
      }));
    }
    return handles;
  }

  @override
  void draw(Uint8List pixels, ui.Size size, {bool antiAlias = false}) {
    for (var i = 0; i < points.length - 1; i++) {
      final point1 = points[i];
      final point2 = points[i + 1];
      final line = Line(point1, point2,
          outlineColor: outlineColor, thickness: thickness);
      line.draw(pixels, size, antiAlias: antiAlias);
    }
    if (closed) {
      final point1 = points[points.length - 1];
      final point2 = points[0];
      final line = Line(point1, point2,
          outlineColor: outlineColor, thickness: thickness);
      line.draw(pixels, size, antiAlias: antiAlias);

      if (fillColor != null) {
        scanlineFill(pixels, size, (x, y) => fillColor!);
      } else if (fillImage != null) {
        scanlineFill(pixels, size, (x, y) {
          final top = topLeft!.dy;
          final left = topLeft!.dx;
          final bottom = bottomRight!.dy;
          final right = bottomRight!.dx;

          var u = (x - left) / (right - left) * fillImage!.width;
          var v = (y - top) / (bottom - top) * fillImage!.height;

          if (u < 0) {
            u = 0;
          } else if (u >= fillImage!.width) {
            u = fillImage!.width - 1;
          }
          if (v < 0) {
            v = 0;
          } else if (v >= fillImage!.height) {
            v = fillImage!.height - 1;
          }
          return fillImage!.getPixel(u.toInt(), v.toInt());
        });
      }
    }
  }

  void updateBoundingBox() {
    final top = points.reduce((value, element) {
      if (element.dy < value.dy) {
        return element;
      }
      return value;
    }).dy;
    final bottom = points.reduce((value, element) {
      if (element.dy > value.dy) {
        return element;
      }
      return value;
    }).dy;
    final left = points.reduce((value, element) {
      if (element.dx < value.dx) {
        return element;
      }
      return value;
    }).dx;
    final right = points.reduce((value, element) {
      if (element.dx > value.dx) {
        return element;
      }
      return value;
    }).dx;
    topLeft = ui.Offset(left, top);
    bottomRight = ui.Offset(right, bottom);
  }

  @override
  bool contains(ui.Offset offset) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final xi = points[i].dx;
      final yi = points[i].dy;
      final xj = points[j].dx;
      final yj = points[j].dy;
      final intersect = ((yi > offset.dy) != (yj > offset.dy)) &&
          (offset.dx < (xj - xi) * (offset.dy - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  @override
  void move(ui.Offset offset) {
    for (var i = 0; i < points.length; i++) {
      points[i] += offset;
    }
    this.offset += offset;
    if (topLeft != null) {
      topLeft = topLeft! + offset;
    }
    if (bottomRight != null) {
      bottomRight = bottomRight! + offset;
    }
  }

  void removePointAt(ui.Offset offset) {
    for (var i = 0; i < points.length; i++) {
      if ((points[i] - offset).distance < 10) {
        points.removeAt(i);
        break;
      }
    }
  }

  static Shape? fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'polygon') {
      final points = <ui.Offset>[];
      for (var i = 0; i < json['points'].length; i++) {
        final point = json['points'][i];
        points.add(ui.Offset(point['x'], point['y']));
      }
      var fillImage = json['fillImage'] != null
          ? ImageData.fromJson(json['fillImage'])
          : null;
      var fillColor =
          json['fillColor'] != null ? ui.Color(json['fillColor']) : null;

      return Polygon(points, ui.Offset.zero,
          closed: json['closed'],
          thickness: json['thickness'],
          outlineColor: ui.Color(json['color']),
          fillColor: fillColor,
          fillImage: fillImage);
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() {
    final points = <Map<String, double>>[];
    for (var i = 0; i < this.points.length; i++) {
      final point = this.points[i];
      points.add({'x': point.dx, 'y': point.dy});
    }
    return {
      'type': 'polygon',
      'points': points,
      'closed': closed,
      'thickness': thickness,
      'color': outlineColor.value,
      'fillColor': fillColor?.value,
      'fillImage': fillImage?.toJson()
    };
  }

  @override
  void accept(ShapeVisitor visitor) {
    visitor.visitPolygon(this);
  }

  void drawPixel(
      Uint8List pixels, ui.Size size, ui.Offset pos, ui.Color color) {
    final x = pos.dx.toInt();
    final y = pos.dy.toInt();
    if (x < 0 || x >= size.width || y < 0 || y >= size.height) {
      return;
    }
    final index = ((x + y * size.width) * 4).round();
    pixels[index] = color.red;
    pixels[index + 1] = color.green;
    pixels[index + 2] = color.blue;
    pixels[index + 3] = color.alpha;
  }

  void scanlineFill(
      Uint8List pixels, ui.Size size, ui.Color Function(int x, int y) color) {
    List<int> sortedIndices = List<int>.generate(points.length, (i) => i);
    sortedIndices.sort((a, b) {
      int yCompare = points[a].dy.compareTo(points[b].dy);
      return yCompare == 0 ? points[a].dx.compareTo(points[b].dx) : yCompare;
    });

    List<EdgeEntry> aet = [];

    for (int y = 0; y < size.height.toInt(); y++) {
      while (sortedIndices.isNotEmpty &&
          points[sortedIndices.first].dy.toInt() == y) {
        int currentIndex = sortedIndices.removeAt(0);
        int prevIndex = (currentIndex - 1 + points.length) % points.length;
        int nextIndex = (currentIndex + 1) % points.length;

        ui.Offset currentPoint = points[currentIndex];
        if (points[nextIndex].dy > currentPoint.dy) {
          aet.add(createEdge(points[currentIndex], points[nextIndex]));
        }
        if (points[prevIndex].dy > currentPoint.dy) {
          aet.add(createEdge(points[currentIndex], points[prevIndex]));
        }
      }

      aet.removeWhere((edge) => edge.yMax.toInt() == y);
      for (var edge in aet) {
        edge.x += edge.dx;
      }

      aet.sort((a, b) => (a.x).compareTo(b.x));

      for (int i = 0; i < aet.length; i += 2) {
        int startX = aet[i].x.toInt();
        int endX = aet[i + 1].x.toInt();
        for (int x = startX; x <= endX; x++) {
          drawPixel(
              pixels, size, ui.Offset(x.toDouble(), y.toDouble()), color(x, y));
        }
      }
    }
  }

  EdgeEntry createEdge(ui.Offset start, ui.Offset end) {
    double dx = (end.dx - start.dx) / (end.dy - start.dy);
    return EdgeEntry(
      x: start.dx,
      yMax: end.dy,
      dx: dx,
    );
  }
}

class EdgeEntry {
  double x;
  double yMax;
  double dx;

  EdgeEntry({
    required this.x,
    required this.yMax,
    required this.dx,
  });
}
