import 'item.dart';

class StorageLocation {
  final String id;
  final String name;
  final String? parentId;
  final String type;
  final String? memo;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StorageLocation({
    required this.id,
    required this.name,
    this.parentId,
    required this.type,
    this.memo,
    this.sortOrder = 0,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  StorageLocation copyWith({
    String? name,
    String? parentId,
    String? type,
    String? memo,
    int? sortOrder,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return StorageLocation(
      id: id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      type: type ?? this.type,
      memo: memo ?? this.memo,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ItemLocation {
  final String itemId;
  final String locationId;
  final bool isPrimary;
  final int qty;
  final String? memo;
  final DateTime updatedAt;

  const ItemLocation({
    required this.itemId,
    required this.locationId,
    required this.isPrimary,
    this.qty = 0,
    this.memo,
    required this.updatedAt,
  });
}

class ItemWithLocations {
  final Item item;
  final StorageLocation? primaryLocation;
  final List<StorageLocation> locations;
  final String? primaryLocationPath;
  final List<String> locationPaths;

  const ItemWithLocations({
    required this.item,
    this.primaryLocation,
    required this.locations,
    this.primaryLocationPath,
    required this.locationPaths,
  });

  int get otherLocationCount {
    final primaryId = primaryLocation?.id;
    if (primaryId == null) return locations.length;
    return locations.where((location) => location.id != primaryId).length;
  }
}

class ItemLocationSummary {
  final StorageLocation? primaryLocation;
  final String? primaryLocationPath;
  final int locationCount;
  final int primaryQty;
  final int totalAssignedQty;

  const ItemLocationSummary({
    required this.primaryLocation,
    required this.primaryLocationPath,
    required this.locationCount,
    this.primaryQty = 0,
    this.totalAssignedQty = 0,
  });

  bool get hasLocation => locationCount > 0;

  int get extraLocationCount {
    if (locationCount <= 1) return 0;
    return locationCount - 1;
  }
}

class LocationItemEntry {
  final Item item;
  final StorageLocation location;
  final String locationPath;
  final bool isPrimary;
  final int qty;

  const LocationItemEntry({
    required this.item,
    required this.location,
    required this.locationPath,
    required this.isPrimary,
    this.qty = 0,
  });
}

class StorageLocationMovement {
  final String id;
  final String itemId;
  final String itemName;
  final String? fromLocationId;
  final String? fromLocationPath;
  final String toLocationId;
  final String toLocationPath;
  final String? memo;
  final DateTime movedAt;

  const StorageLocationMovement({
    required this.id,
    required this.itemId,
    required this.itemName,
    this.fromLocationId,
    this.fromLocationPath,
    required this.toLocationId,
    required this.toLocationPath,
    this.memo,
    required this.movedAt,
  });
}

class StorageLocationType {
  static const room = 'room';
  static const shelf = 'shelf';
  static const rack = 'rack';
  static const box = 'box';
  static const warehouse = 'warehouse';
  static const store = 'store';
  static const drawer = 'drawer';
  static const section = 'section';
  static const custom = 'custom';

  static const values = [
    room,
    warehouse,
    store,
    shelf,
    rack,
    box,
    drawer,
    section,
    custom,
  ];

  static String label(String type) {
    switch (type) {
      case room:
        return '작업실';
      case warehouse:
        return '창고';
      case store:
        return '매장';
      case shelf:
        return '선반';
      case rack:
        return '랙';
      case box:
        return '박스';
      case drawer:
        return '서랍';
      case section:
        return '칸';
      case custom:
      default:
        return '기타';
    }
  }
}
